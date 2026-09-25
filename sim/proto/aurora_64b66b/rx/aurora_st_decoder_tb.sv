// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Decoder stimulus from aurora_st_decoder_tb.vhdl ("simple"): four 66-bit
// lanes alternate a data/SEP beat with an all-idle beat for 10 us.
// Checks the byte-swapped payloads and the SEP beat (empty 5).

`timescale 1ns/1ps

module aurora_st_decoder_tb;

  localparam int c_N_LANES = 4;
  localparam int c_DATA_W  = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W   = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_EMPTY_W = colibri_utils::log2ceil(c_DATA_W / 8);
  localparam logic [c_ENC_W-1:0] c_IDLE = colibri_aurora_const::c_IDLE_WORD;
  localparam logic [c_DATA_W-1:0] c_AA =
    64'hBBBB_BBBB_AAAA_AAAA;
  localparam logic [c_DATA_W-1:0] c_EE =
    64'hFFFF_FFFF_EEEE_EEEE;
  localparam logic [c_DATA_W-1:0] c_SEP_DATA =
    64'h0033_2211_DDCC_0000;

  logic                 clk = 1'b0;
  logic                 reset = 1'b1;
  logic                 src_sop;
  logic                 src_eop;
  logic                 src_valid;
  logic                 src_error;
  logic [c_DATA_W-1:0]  src_data;
  logic [c_EMPTY_W-1:0] src_empty;
  logic [c_ENC_W-1:0]   snk_data [0:c_N_LANES-1];
  logic                 snk_ready;
  logic                 snk_valid = 1'b1;
  logic                 v_b = 1'b0;

  int seen_valid;
  int seen_aa;
  int seen_ee;
  int seen_sep;
  int seen_sop;
  int seen_error;
  int driven;

  typedef struct {
    logic [c_DATA_W-1:0] data;
    logic                sop;
    logic                eop;
    logic                err;
    logic [c_EMPTY_W-1:0] empty;
  } beat_t;

  beat_t cap[$];

  always #2500ps clk = ~clk;

  aurora_st_decoder #(
    .g_N_LANES(c_N_LANES),
    .g_FIFO_WORDS(8)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_link_up_i(1'b1),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_sop_o(src_sop),
    .src_eop_o(src_eop),
    .src_valid_o(src_valid),
    .src_error_o(src_error),
    .src_data_o(src_data),
    .src_empty_o(src_empty)
  );

  // NBA on the clock, not a delayed initial: Verilator 5.020 can miss
  // unpacked-array writes that an initial applies with #1ps.
  always_ff @(posedge clk) begin : proc_input
    if (reset) begin
      v_b    <= 1'b0;
      driven <= 0;
      for (int lane = 0; lane < c_N_LANES; lane++)
        snk_data[lane] <= c_IDLE;
    end else if (snk_ready) begin
      v_b    <= ~v_b;
      driven <= driven + 1;
      if (!v_b) begin
        snk_data[0] <= {2'b01, 64'hAAAA_AAAA_BBBB_BBBB};
        snk_data[1] <= c_IDLE;
        snk_data[2] <= {2'b01, 64'hEEEE_EEEE_FFFF_FFFF};
        snk_data[3] <= {2'b10, 8'h1e, 8'h03, 48'hCCDD_1122_3300};
      end else begin
        for (int lane = 0; lane < c_N_LANES; lane++)
          snk_data[lane] <= c_IDLE;
      end
    end
  end

  initial begin : proc_monitor
    seen_valid = 0;
    seen_aa    = 0;
    seen_ee    = 0;
    seen_sep   = 0;
    seen_sop   = 0;
    seen_error = 0;
    forever begin
      @(posedge clk);
      #1ps;
      if (!reset && src_valid) begin
        seen_valid++;
        if (src_sop)
          seen_sop++;
        if (src_error)
          seen_error++;
        if (src_data == c_AA)
          seen_aa++;
        if (src_data == c_EE)
          seen_ee++;
        if (src_eop && (src_empty == 3'd5) && (src_data == c_SEP_DATA))
          seen_sep++;
        if (cap.size() < 24) begin
          beat_t beat;
          beat.data  = src_data;
          beat.sop   = src_sop;
          beat.eop   = src_eop;
          beat.err   = src_error;
          beat.empty = src_empty;
          cap.push_back(beat);
        end
      end
    end
  end

  initial begin : proc_main
    reset = 1'b1;
    repeat (10) @(posedge clk);
    reset = 1'b0;
    #10us;

    if ((driven < 10) || (seen_valid == 0) || (seen_aa == 0) ||
        (seen_ee == 0) || (seen_sep == 0) || (seen_sop == 0) ||
        (seen_error != 0)) begin
      for (int i = 0; i < cap.size(); i++)
        $display("beat %0d data %h sop %b eop %b empty %0d err %b",
                 i, cap[i].data, cap[i].sop, cap[i].eop, cap[i].empty, cap[i].err);
      $fatal(1, "decoder check failed driven=%0d valid=%0d aa=%0d ee=%0d sep=%0d sop=%0d err=%0d",
             driven, seen_valid, seen_aa, seen_ee, seen_sep, seen_sop, seen_error);
    end

    $display("PASS aurora_st_decoder_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #50us;
    $fatal(1, "aurora_st_decoder_tb timeout");
  end

endmodule
