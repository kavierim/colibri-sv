// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Lane-mismatch scenario from aurora_lane_mismatch_tb.vhdl: a 4-lane
// transmitter drives only lane 0 into a 1-lane receiver. The pass condition
// is src_error_o high within 100 us. No user packet is sent; idle and
// channel-bond words are enough for the single-lane bond check.

`timescale 1ns/1ps

module aurora_lane_mismatch_tb;

  localparam int c_LANE_WIDTH = 32;
  localparam int c_TX_LANES   = 4;
  localparam int c_DATA_W     = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_EMPTY_W    = colibri_utils::log2ceil(c_DATA_W / 8);
  localparam int c_GBX_BUF    = 20 * colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_CLK_PS     = 25000;

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
  logic [c_LANE_WIDTH-1:0] tx_data [0:c_TX_LANES-1];
  logic [c_TX_LANES-1:0]   tx_valid;
  logic [c_LANE_WIDTH-1:0] rx_data [0:0];
  logic [0:0]              rx_valid;
  logic                    rx_error;
  logic                    src_sop;
  logic                    src_eop;
  logic                    src_valid;
  logic [c_DATA_W-1:0]     src_data;
  logic [c_EMPTY_W-1:0]    src_empty;
  logic                    link_up;

  always #12500ps av_clk = ~av_clk;
  always #12500ps elink_clk = ~elink_clk;

  assign rx_data[0] = tx_data[0];
  assign rx_valid   = tx_valid[0];

  aurora_tx #(
    .g_N_LANES(c_TX_LANES),
    .g_LANE_WIDTH(c_LANE_WIDTH),
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
    .src_ready_i({c_TX_LANES{1'b1}})
  );

  aurora_rx #(
    .g_N_LANES(1),
    .g_LANE_WIDTH(c_LANE_WIDTH),
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
    .src_error_o(rx_error),
    .src_data_o(src_data),
    .src_empty_o(src_empty),
    .src_link_up_o(link_up)
  );

  initial begin
    reset_tx = 1'b1;
    reset_rx = 1'b1;
    #(c_CLK_PS * 1ps);
    reset_tx = 1'b0;
    #(c_CLK_PS * 7 * 1ps);
    reset_rx = 1'b0;
  end

  initial begin : proc_main
    fork
      begin
        wait (rx_error == 1'b1);
      end
      begin
        #100us;
        $fatal(1, "lane mismatch: src_error_o stayed low for 100 us (link_up=%b)", link_up);
      end
    join_any
    disable fork;
    if (rx_error != 1'b1)
      $fatal(1, "lane mismatch: src_error_o was not high");
    $display("PASS aurora_lane_mismatch_tb");
    $finish;
  end

endmodule
