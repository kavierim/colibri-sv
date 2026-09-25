// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Loopback from aurora_loopback_tb.vhdl ("loopback_encode_decode").
// run.py sweeps lane widths 8, 16, 32 and lane counts 1..4, with delay and
// error injection left at their defaults (off). A sync packet is dropped by
// the decoder. Each later packet is a downto slice of an incrementing byte
// array and must match on the receive stream.
// VHDL repeats 21 packets (lengths 30 down to 10) three times and allows a
// 10 ms scoreboard timeout. This bench sends one pass of lengths 18 down to
// 10, which still includes a multiple of 8 bytes, and stops when the match
// completes.

`timescale 1ns/1ps

module aurora_loopback_harness #(
  parameter int g_NUM_LANES  = 1,
  parameter int g_LANE_WIDTH = 8
) (
  output logic done_o
);

  localparam int c_N_PACKETS = 8;
  localparam int c_MIN_SIZE  = 10;
  localparam int c_HI        = c_MIN_SIZE + c_N_PACKETS - 1;
  localparam int c_DATA_W    = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_EMPTY_W   = colibri_utils::log2ceil(c_DATA_W / 8);
  localparam int c_GBX_BUF   = 20 * colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_CLK_PS    = 25000;

  logic                    av_clk = 1'b0;
  logic                    elink_clk = 1'b0;
  logic                    reset_tx = 1'b1;
  logic                    reset_rx = 1'b1;
  logic                    snk_sop = 1'b0;
  logic                    snk_eop = 1'b0;
  logic                    snk_valid = 1'b0;
  logic                    snk_ready;
  logic [c_DATA_W-1:0]     snk_data = '0;
  logic [c_EMPTY_W-1:0]    snk_empty = '0;
  logic [g_LANE_WIDTH-1:0] tx_data [0:g_NUM_LANES-1];
  logic [g_LANE_WIDTH-1:0] rx_data [0:g_NUM_LANES-1];
  logic [g_NUM_LANES-1:0]  tx_valid;
  logic [g_NUM_LANES-1:0]  rx_valid;
  logic                    src_sop;
  logic                    src_eop;
  logic                    src_valid;
  logic                    src_error;
  logic [c_DATA_W-1:0]     src_data;
  logic [c_EMPTY_W-1:0]    src_empty;
  logic                    link_up;

  int         exp_len_q[$];
  logic [7:0] exp_byte_q[$];
  int         got_packets;
  int         exp_packets;
  // Written only from proc_main. Verilator 5.020 duplicates a flag
  // that is assigned from more than one initial process.
  int         checking;

  always #12500ps av_clk = ~av_clk;
  always #12500ps elink_clk = ~elink_clk;

  assign rx_data  = tx_data;
  assign rx_valid = tx_valid;

  aurora_tx #(
    .g_N_LANES(g_NUM_LANES),
    .g_LANE_WIDTH(g_LANE_WIDTH),
    .g_GBX_BUF_SIZE(c_GBX_BUF)
  ) tx_dut (
    .snk_clk_i(av_clk),
    .snk_reset_i(reset_tx),
    .src_clk_i(elink_clk),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .snk_data_i(snk_data),
    .snk_empty_i(snk_empty),
    .src_data_o(tx_data),
    .src_valid_o(tx_valid),
    .src_ready_i({g_NUM_LANES{1'b1}})
  );

  aurora_rx #(
    .g_N_LANES(g_NUM_LANES),
    .g_LANE_WIDTH(g_LANE_WIDTH),
    .g_GBX_BUF_SIZE(c_GBX_BUF)
  ) rx_dut (
    .snk_clk_i(elink_clk),
    .src_clk_i(av_clk),
    .src_reset_i(reset_rx),
    .snk_valid_i(rx_valid),
    .snk_data_i(rx_data),
    .src_sop_o(src_sop),
    .src_eop_o(src_eop),
    .src_valid_o(src_valid),
    .src_error_o(src_error),
    .src_data_o(src_data),
    .src_empty_o(src_empty),
    .src_link_up_o(link_up)
  );

  function automatic logic [7:0] span_byte(input int hi, input int offset);
    return 8'(hi - offset);
  endfunction

  task automatic tick;
    @(posedge av_clk);
    #1ps;
  endtask

  task automatic send_span(input int hi, input int lo);
    int nwords;
    int nbytes;
    int remain;
    int empty;
    int guard;
    logic [c_DATA_W-1:0] word;
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
        if (guard > 200000)
          $fatal(1, "loopback ready timeout lanes=%0d width=%0d", g_NUM_LANES, g_LANE_WIDTH);
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

  initial begin
    reset_tx = 1'b1;
    reset_rx = 1'b1;
    #(c_CLK_PS * 1ps);
    reset_tx = 1'b0;
    #(c_CLK_PS * 7 * 1ps);
    reset_rx = 1'b0;
  end

  initial begin : proc_monitor
    logic [7:0] got[$];
    int nbytes;
    int pkt_i;
    got_packets = 0;
    pkt_i       = 0;
    forever begin
      @(posedge av_clk);
      #1ps;
      if (reset_rx) begin
        got = {};
      end else if ((checking != 0) && src_valid) begin
        if (src_error)
          $fatal(1, "loopback error lanes=%0d width=%0d packet=%0d",
                 g_NUM_LANES, g_LANE_WIDTH, pkt_i);
        if (src_sop && (got.size() != 0))
          $fatal(1, "loopback SOP while open lanes=%0d width=%0d packet=%0d",
                 g_NUM_LANES, g_LANE_WIDTH, pkt_i);
        if (!src_sop && (got.size() == 0))
          $fatal(1, "loopback data without SOP lanes=%0d width=%0d",
                 g_NUM_LANES, g_LANE_WIDTH);
        if (!src_eop && (src_empty != '0))
          $fatal(1, "loopback empty before EOP lanes=%0d width=%0d",
                 g_NUM_LANES, g_LANE_WIDTH);
        nbytes = src_eop ? (8 - int'(src_empty)) : 8;
        if ((nbytes < 1) || (nbytes > 8))
          $fatal(1, "loopback empty %0d lanes=%0d width=%0d",
                 src_empty, g_NUM_LANES, g_LANE_WIDTH);
        for (int b = 0; b < nbytes; b++)
          got.push_back(src_data[(c_DATA_W - 1) - (b * 8) -: 8]);
        if (src_eop) begin
          if (exp_len_q.size() == 0)
            $fatal(1, "loopback unexpected packet lanes=%0d width=%0d len=%0d",
                   g_NUM_LANES, g_LANE_WIDTH, got.size());
          if (got.size() != exp_len_q[0])
            $fatal(1, "loopback length lanes=%0d width=%0d pkt=%0d got=%0d exp=%0d",
                   g_NUM_LANES, g_LANE_WIDTH, pkt_i, got.size(), exp_len_q[0]);
          for (int b = 0; b < got.size(); b++) begin
            if (got[b] != exp_byte_q[0])
              $fatal(1, "loopback data lanes=%0d width=%0d pkt=%0d byte=%0d got=%02x exp=%02x",
                     g_NUM_LANES, g_LANE_WIDTH, pkt_i, b, got[b], exp_byte_q[0]);
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
    done_o      = 1'b0;
    exp_packets = 0;
    checking    = 0;
    wait (reset_rx == 1'b0);
    guard = 0;
    while (link_up != 1'b1) begin
      tick();
      guard++;
      if (guard > 40000)
        $fatal(1, "loopback link_up timeout lanes=%0d width=%0d", g_NUM_LANES, g_LANE_WIDTH);
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
      if (guard > 400000)
        $fatal(1, "loopback got %0d of %0d lanes=%0d width=%0d",
               got_packets, exp_packets, g_NUM_LANES, g_LANE_WIDTH);
    end
    done_o = 1'b1;
  end

endmodule

module aurora_loopback_tb;

  logic done_flag [0:2][0:3];

  for (genvar wi = 0; wi < 3; wi++) begin : gen_width
    for (genvar li = 0; li < 4; li++) begin : gen_lanes
      localparam int c_W = (wi == 0) ? 8 : ((wi == 1) ? 16 : 32);
      localparam int c_L = li + 1;
      aurora_loopback_harness #(
        .g_NUM_LANES(c_L),
        .g_LANE_WIDTH(c_W)
      ) harness (
        .done_o(done_flag[wi][li])
      );
    end
  end

  initial begin : proc_join
    for (int wi = 0; wi < 3; wi++)
      for (int li = 0; li < 4; li++)
        wait (done_flag[wi][li] == 1'b1);
    $display("PASS aurora_loopback_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #2ms;
    $fatal(1, "aurora_loopback_tb timeout");
  end

endmodule
