// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/packet_cc_fifo/packet_cc_fifo_tb.vhdl.
// 21 packets, lengths 30 down to 10, cross from a 40 MHz write clock to 60 MHz.
// The size sideband is the packet length in bytes.

`timescale 1ns/1ps

module packet_cc_fifo_tb;

  localparam int c_N_PACKETS        = 20;
  localparam int c_MIN_SIZE         = 10;
  localparam int c_TOTAL            = c_MIN_SIZE + c_N_PACKETS;
  localparam int c_MAX_PACKET_BYTES = 32;
  localparam int c_NUM_PACKETS      = 4;
  localparam int c_DATA_WIDTH       = 16;
  localparam int c_PKT_SIZE_BITS    = 16;
  localparam int c_EMPTY_W          = colibri_utils::downto_width(colibri_utils::log2ceil(c_DATA_WIDTH / 8));
  localparam int c_NSYM             = c_DATA_WIDTH / 8;
  localparam int c_N_PKT            = c_N_PACKETS + 1;

  logic wrclk = 1'b0;
  logic rdclk = 1'b0;
  logic reset = 1'b1;
  logic snk_ready;
  logic snk_valid = 1'b0;
  logic snk_sop = 1'b0;
  logic snk_eop = 1'b0;
  logic [c_EMPTY_W-1:0] snk_empty = '0;
  logic [c_DATA_WIDTH-1:0] snk_data = '0;
  logic src_ready = 1'b0;
  logic src_valid, src_sop, src_eop;
  logic [c_EMPTY_W-1:0] src_empty;
  logic [c_DATA_WIDTH-1:0] src_data;
  logic [c_PKT_SIZE_BITS-1:0] src_size;

  always #12.5 wrclk = ~wrclk;
  always #8.333 rdclk = ~rdclk;

  packet_cc_fifo #(
    .g_MAX_PACKET_BYTES(c_MAX_PACKET_BYTES),
    .g_NUM_PACKETS(c_NUM_PACKETS),
    .g_PKT_SIZE_BITS(c_PKT_SIZE_BITS),
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) dut (
    .wrclk_i(wrclk),
    .reset_i(reset),
    .rdclk_i(rdclk),
    .wrusedp_o(),
    .rdusedp_o(),
    .wrempty_o(),
    .wrfull_o(),
    .rdempty_o(),
    .rdfull_o(),
    .snk_ready_o(snk_ready),
    .snk_valid_i(snk_valid),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_empty_i(snk_empty),
    .snk_data_i(snk_data),
    .src_ready_i(src_ready),
    .src_valid_o(src_valid),
    .src_sop_o(src_sop),
    .src_eop_o(src_eop),
    .src_empty_o(src_empty),
    .src_data_o(src_data),
    .src_size_o(src_size)
  );

  logic [7:0] expb [$];
  int lens [$];
  bit tx_done;

  function automatic logic [7:0] msg_byte(input int idx);
    return 8'(idx % 256);
  endfunction

  task automatic send_packet(input int nbytes);
    int nbeats;
    int empty_last;
    int bi;
    nbeats = (nbytes + c_NSYM - 1) / c_NSYM;
    empty_last = nbeats * c_NSYM - nbytes;
    for (int b = 0; b < nbeats; b++) begin
      @(negedge wrclk);
      snk_valid = 1'b1;
      snk_sop   = (b == 0);
      snk_eop   = (b == nbeats - 1);
      snk_empty = snk_eop ? c_EMPTY_W'(empty_last) : '0;
      for (int s = 0; s < c_NSYM; s++) begin
        bi = b * c_NSYM + s;
        snk_data[(c_NSYM - 1 - s) * 8 +: 8] = (bi < nbytes) ? msg_byte((c_TOTAL - 1) - bi) : 8'h00;
      end
      do @(posedge wrclk); while (!snk_ready);
    end
    @(negedge wrclk);
    snk_valid = 1'b0;
  endtask

  initial begin
    tx_done = 1'b0;
    repeat (5) @(posedge wrclk);
    @(negedge wrclk);
    reset = 1'b0;
    repeat (10) @(posedge wrclk);
    for (int i = 0; i < c_N_PKT; i++) begin
      int nbytes;
      nbytes = c_TOTAL - i;
      lens.push_back(nbytes);
      for (int k = 0; k < nbytes; k++)
        expb.push_back(msg_byte((c_TOTAL - 1) - k));
      send_packet(nbytes);
    end
    tx_done = 1'b1;
  end

  initial begin
    int got;
    int exp_len;
    int n_got;
    int guard;
    n_got = 0;
    guard = 0;
    @(negedge reset);
    repeat (4) @(posedge rdclk);
    src_ready = 1'b1;
    while (n_got < c_N_PKT) begin
      @(negedge rdclk);
      src_ready = ($urandom_range(0, 4) != 0);
      @(posedge rdclk);
      // Sample before the nonblocking update. This edge accepts the word
      // that has been presented since the previous edge.
      guard++;
      if (guard > 40000)
        $fatal(1, "packet_cc_fifo_tb: timeout after %0d packets", n_got);
      if (src_valid && src_ready) begin
        int nvalid;
        if (src_sop) begin
          if (lens.size() == 0)
            $fatal(1, "packet_cc_fifo_tb: unexpected sop");
          exp_len = lens.pop_front();
          if (src_size !== c_PKT_SIZE_BITS'(exp_len))
            $fatal(1, "packet_cc_fifo_tb: size got %0d exp %0d", src_size, exp_len);
          got = 0;
        end
        nvalid = src_eop ? (c_NSYM - int'(src_empty)) : c_NSYM;
        for (int s = 0; s < nvalid; s++) begin
          logic [7:0] exp;
          logic [7:0] gotb;
          if (expb.size() == 0)
            $fatal(1, "packet_cc_fifo_tb: extra byte");
          exp  = expb.pop_front();
          gotb = src_data[(c_NSYM - 1 - s) * 8 +: 8];
          if (gotb !== exp)
            $fatal(1, "packet_cc_fifo_tb: pkt %0d byte %0d sop %0b eop %0b empty %0d data %h got %h exp %h",
                   n_got, got, src_sop, src_eop, src_empty, src_data, gotb, exp);
          got++;
        end
        if (src_eop) begin
          if (got != exp_len)
            $fatal(1, "packet_cc_fifo_tb: length got %0d exp %0d", got, exp_len);
          n_got++;
        end
      end
    end
    if (!tx_done)
      $fatal(1, "packet_cc_fifo_tb: receiver finished early");
    $display("PASS packet_cc_fifo_tb");
    $finish;
  end

  initial begin
    #1_000_000;
    $fatal(1, "packet_cc_fifo_tb: timeout");
  end

endmodule
