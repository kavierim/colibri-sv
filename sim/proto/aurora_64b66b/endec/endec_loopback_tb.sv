// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Direct encoder-to-decoder loopback from endec_loopback_tb.vhdl.
// A sync packet is sent and dropped by the decoder. The following packets
// are a downto slice of an incrementing byte array and must match exactly.
// VHDL uses 32 packets (lengths 33 down to 1). The length run is capped at
// 9 down to 1 so the same match finishes quickly, including a multiple of
// 8 bytes and a 1-byte packet.

`timescale 1ns/1ps

module endec_loopback_tb;

  localparam int c_N_LANES   = 4;
  localparam int c_N_PACKETS = 8;
  localparam int c_MIN_SIZE  = 1;
  localparam int c_HI        = c_MIN_SIZE + c_N_PACKETS - 1;
  localparam int c_DATA_W    = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W     = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_EMPTY_W   = colibri_utils::log2ceil(c_DATA_W / 8);
  logic                      clk = 1'b0;
  logic                      reset = 1'b1;
  logic                      snk_sop = 1'b0;
  logic                      snk_eop = 1'b0;
  logic                      snk_valid = 1'b0;
  logic                      snk_ready;
  logic [c_DATA_W-1:0]       snk_data = '0;
  logic [c_EMPTY_W-1:0]      snk_empty = '0;
  logic [c_ENC_W-1:0]        lane_data [0:c_N_LANES-1];
  logic [c_N_LANES-1:0]      lane_valid;
  logic                      dec_ready;
  logic                      src_sop;
  logic                      src_eop;
  logic                      src_valid;
  logic                      src_error;
  logic [c_DATA_W-1:0]       src_data;
  logic [c_EMPTY_W-1:0]      src_empty;

  int          exp_len_q[$];
  logic [7:0]  exp_byte_q[$];
  int          got_packets;
  int          exp_packets;
  // Written only from proc_main. A flag assigned in two initials is
  // duplicated per process by Verilator 5.020.
  int          checking;

  always #3125ps clk = ~clk;

  aurora_st_encoder #(
    .g_N_LANES(c_N_LANES)
  ) encoder_dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .snk_data_i(snk_data),
    .snk_empty_i(snk_empty),
    .src_data_o(lane_data),
    .src_ready_i({c_N_LANES{dec_ready}}),
    .src_valid_o(lane_valid)
  );

  aurora_st_decoder #(
    .g_N_LANES(c_N_LANES)
  ) decoder_dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_link_up_i(1'b1),
    .snk_data_i(lane_data),
    .snk_valid_i(&lane_valid),
    .snk_ready_o(dec_ready),
    .src_sop_o(src_sop),
    .src_eop_o(src_eop),
    .src_valid_o(src_valid),
    .src_error_o(src_error),
    .src_data_o(src_data),
    .src_empty_o(src_empty)
  );

  function automatic logic [7:0] span_byte(input int hi, input int offset);
    return 8'(hi - offset);
  endfunction

  task automatic tick;
    @(posedge clk);
    #1ps;
  endtask

  task automatic send_span(input int hi, input int lo);
    int nwords;
    int nbytes;
    int remain;
    int empty;
    logic [c_DATA_W-1:0] word;
    int guard;
    nwords = ((hi - lo + 1) + 7) / 8;
    for (int word_i = 0; word_i < nwords; word_i++) begin
      remain = (hi - lo + 1) - word_i * 8;
      nbytes = (remain > 8) ? 8 : remain;
      empty  = 8 - nbytes;
      word   = '0;
      for (int b = 0; b < nbytes; b++)
        word[(c_DATA_W - 1) - (b * 8) -: 8] = span_byte(hi, word_i * 8 + b);
      guard = 0;
      while (snk_ready != 1'b1) begin
        tick();
        guard++;
        if (guard > 20000)
          $fatal(1, "endec snk_ready timeout");
      end
      snk_data  = word;
      snk_empty = c_EMPTY_W'(empty);
      snk_sop   = (word_i == 0);
      snk_eop   = (word_i == nwords - 1);
      snk_valid = 1'b1;
      tick();
    end
    snk_valid = 1'b0;
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
    tick();
  endtask

  task automatic queue_span(input int hi, input int lo);
    int nbytes;
    nbytes = hi - lo + 1;
    exp_len_q.push_back(nbytes);
    for (int b = 0; b < nbytes; b++)
      exp_byte_q.push_back(span_byte(hi, b));
    exp_packets++;
  endtask

  initial begin : proc_monitor
    logic [7:0] got[$];
    int nbytes;
    int pkt_i;
    got_packets = 0;
    pkt_i       = 0;
    forever begin
      @(posedge clk);
      #1ps;
      if (reset) begin
        got = {};
      end else if ((checking != 0) && src_valid) begin
        if (src_error)
          $fatal(1, "endec src_error during packet %0d", pkt_i);
        if (src_sop && (got.size() != 0))
          $fatal(1, "endec SOP while packet %0d still open", pkt_i);
        if (!src_sop && (got.size() == 0))
          $fatal(1, "endec data without SOP at packet %0d", pkt_i);
        if (!src_eop && (src_empty != '0))
          $fatal(1, "endec empty set before EOP");
        nbytes = src_eop ? (8 - int'(src_empty)) : 8;
        if ((nbytes < 1) || (nbytes > 8))
          $fatal(1, "endec empty %0d out of range", src_empty);
        for (int b = 0; b < nbytes; b++)
          got.push_back(src_data[(c_DATA_W - 1) - (b * 8) -: 8]);
        if (src_eop) begin
          if (exp_len_q.size() == 0)
            $fatal(1, "endec unexpected packet length %0d", got.size());
          if (got.size() != exp_len_q[0])
            $fatal(1, "endec packet %0d length got %0d exp %0d",
                   pkt_i, got.size(), exp_len_q[0]);
          for (int b = 0; b < got.size(); b++) begin
            if (got[b] != exp_byte_q[0])
              $fatal(1, "endec packet %0d byte %0d got %02x exp %02x",
                     pkt_i, b, got[b], exp_byte_q[0]);
            exp_byte_q.pop_front();
          end
          exp_len_q.pop_front();
          got = {};
          got_packets++;
          pkt_i++;
        end
      end
    end
  end

  initial begin : proc_main
    int guard;
    exp_packets = 0;
    checking    = 0;
    reset = 1'b1;
    repeat (4) @(posedge clk);
    reset = 1'b0;

    guard = 0;
    while (snk_ready != 1'b1) begin
      tick();
      guard++;
      if (guard > 5000)
        $fatal(1, "endec encoder ready timeout");
    end

    for (int i = 0; i <= c_N_PACKETS; i++)
      queue_span(c_HI, i);
    checking = 1;
    send_span(c_HI, 0);
    for (int i = 0; i <= c_N_PACKETS; i++)
      send_span(c_HI, i);

    guard = 0;
    while (got_packets != exp_packets) begin
      tick();
      guard++;
      if (guard > 8000)
        $fatal(1, "endec received %0d of %0d packets", got_packets, exp_packets);
    end
    repeat (64) tick();
    if (got_packets != exp_packets)
      $fatal(1, "endec extra packets after the scoreboard drained");

    $display("PASS endec_loopback_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #500us;
    $fatal(1, "endec_loopback_tb timeout");
  end

endmodule
