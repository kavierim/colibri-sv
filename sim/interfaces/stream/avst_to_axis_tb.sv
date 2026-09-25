// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Avalon-ST to AXI-Stream. Same packets as avst_to_axis_tb, both byte orders.
// tready is low outside a packet so the bound PSL assumptions hold.
module avst_to_axis_harness #(
  parameter colibri_types::endian_t g_AVST_ENDIANNESS = colibri_types::BIG,
  parameter int c_DATA_W = 32,
  localparam int c_KEEP_W  = colibri_utils::downto_width(c_DATA_W / 8),
  localparam int c_EMPTY_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_DATA_W / 8)),
  localparam int c_BYTES   = c_DATA_W / 8,
  localparam int c_N_PACKETS = 20,
  localparam int c_MSG_LEN   = 10 + c_N_PACKETS
) (
  output logic done
);

  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    snk_ready;
  logic                    snk_valid = 1'b0;
  logic                    snk_sop = 1'b0;
  logic                    snk_eop = 1'b0;
  logic [c_EMPTY_W-1:0]    snk_empty = '0;
  logic [c_DATA_W-1:0]     snk_data = '0;
  logic                    src_tready = 1'b0;
  logic                    src_tvalid;
  logic                    src_tlast;
  logic [c_KEEP_W-1:0]     src_tkeep;
  logic [c_DATA_W-1:0]     src_tdata;

  logic [7:0] exp_bytes [$];
  int         exp_len [$];
  int         got_i;
  int         pkt_got;
  int         pkt_left;

  always #5 clk = ~clk;

  avst_to_axis #(
    .g_DATA_WIDTH      (c_DATA_W),
    .g_AVST_ENDIANNESS (g_AVST_ENDIANNESS)
  ) dut (
    .clk_i        (clk),
    .reset_i      (reset),
    .snk_ready_o  (snk_ready),
    .snk_valid_i  (snk_valid),
    .snk_sop_i    (snk_sop),
    .snk_eop_i    (snk_eop),
    .snk_empty_i  (snk_empty),
    .snk_data_i   (snk_data),
    .src_tready_i (src_tready),
    .src_tvalid_o (src_tvalid),
    .src_tlast_o  (src_tlast),
    .src_tkeep_o  (src_tkeep),
    .src_tdata_o  (src_tdata)
  );

  function automatic logic [c_DATA_W-1:0] pack_avst(input int base, input int n);
    logic [c_DATA_W-1:0] w;
    w = '0;
    for (int i = 0; i < n; i++) begin
      if (g_AVST_ENDIANNESS == colibri_types::BIG)
        w[c_DATA_W-1 - i*8 -: 8] = exp_bytes[base+i];
      else
        w[i*8 +: 8] = exp_bytes[base+i];
    end
    return w;
  endfunction

  always @(posedge clk) begin : proc_check
    int n;
    logic [7:0] b;
    if (!reset && src_tvalid && src_tready) begin
      n = 0;
      for (int i = 0; i < c_KEEP_W; i++)
        if (src_tkeep[i])
          n++;
      if (n < 1)
        $fatal(1, "avst_to_axis empty keep");
      if (!src_tlast && (src_tkeep != {c_KEEP_W{1'b1}}))
        $fatal(1, "avst_to_axis partial keep before last");
      for (int i = 0; i < n; i++) begin
        b = src_tdata[i*8 +: 8];
        if (got_i >= exp_bytes.size())
          $fatal(1, "avst_to_axis extra byte");
        if (b !== exp_bytes[got_i])
          $fatal(1, "avst_to_axis data mismatch at %0d: got %02h exp %02h",
                 got_i, b, exp_bytes[got_i]);
        got_i++;
        pkt_got++;
      end
      if (src_tlast) begin
        if (pkt_got != exp_len[0])
          $fatal(1, "avst_to_axis length got %0d exp %0d", pkt_got, exp_len[0]);
        exp_len.pop_front();
        pkt_got = 0;
        pkt_left--;
      end
    end
  end

  initial begin : proc_seq
    int len;
    int base;
    int n;
    int guard;
    bit first;
    done    = 1'b0;
    got_i   = 0;
    pkt_got = 0;
    base    = 0;
    for (int i = 0; i <= c_N_PACKETS; i++) begin
      len = c_MSG_LEN - i;
      exp_len.push_back(len);
      for (int k = 0; k < len; k++)
        exp_bytes.push_back(8'(c_MSG_LEN - 1 - k));
    end
    pkt_left = exp_len.size();

    @(posedge clk);
    #1;
    reset = 1'b0;
    repeat (4) @(posedge clk);

    for (int i = 0; i <= c_N_PACKETS; i++) begin
      len   = c_MSG_LEN - i;
      first = 1'b1;
      while (len > 0) begin
        n = (len > c_BYTES) ? c_BYTES : len;
        #1;
        snk_valid  = 1'b1;
        snk_sop    = first;
        snk_eop    = (n == len);
        snk_empty  = c_EMPTY_W'(c_BYTES - n);
        snk_data   = pack_avst(base, n);
        src_tready = 1'b1;
        @(posedge clk);
        guard = 0;
        while (!(snk_ready && snk_valid)) begin
          @(posedge clk);
          #1;
          guard++;
          if (guard > 1000)
            $fatal(1, "avst_to_axis ready timeout");
        end
        first = 1'b0;
        base += n;
        len  -= n;
      end
      // Idle gap: valid and ready must both be low when sop is low.
      #1;
      snk_valid  = 1'b0;
      snk_sop    = 1'b0;
      snk_eop    = 1'b0;
      snk_empty  = '0;
      src_tready = 1'b0;
      @(posedge clk);
    end

    guard = 0;
    while (pkt_left != 0) begin
      @(posedge clk);
      #1;
      guard++;
      if (guard > 10000)
        $fatal(1, "avst_to_axis output timeout");
    end
    repeat (4) @(posedge clk);
    done = 1'b1;
  end

endmodule

module avst_to_axis_tb;
  logic [1:0] done;

  avst_to_axis_harness #(.g_AVST_ENDIANNESS(colibri_types::BIG)) u_big (.done(done[0]));
  avst_to_axis_harness #(.g_AVST_ENDIANNESS(colibri_types::LITTLE)) u_little (.done(done[1]));

  initial begin
    wait (&done);
    $display("avst_to_axis_tb PASS");
    $finish;
  end

  initial begin
    #1ms;
    $fatal(1, "avst_to_axis_tb watchdog");
  end
endmodule
