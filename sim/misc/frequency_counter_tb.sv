// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-check for frequency_counter. Two measured clocks must land inside
// the same uncertainty window as the VHDL test. The first sample is ignored.

`timescale 1ns/1ps

module frequency_counter_tb;

  // verilator lint_off REALCVT
  localparam time c_CLK_REF_PERIOD = 10ns;
  localparam time c_CLK_A_PERIOD   = 25ns;
  localparam time c_CLK_B_PERIOD   = 4158ps;
  // verilator lint_on REALCVT
  localparam int unsigned c_NUM_CLOCKS     = 2;
  localparam int unsigned c_DATA_WIDTH     = 32;
  localparam int unsigned c_SAMPLE_FREQ_HZ = 1000;
  localparam int c_THRES = 4;

  // 1s / period, truncated the way VHDL `time / time` does at 1 ps.
  localparam int unsigned c_CLK_REF_FREQ_HZ = 100_000_000;
  localparam int unsigned c_CLK_A_FREQ      = 40_000_000;
  localparam int unsigned c_CLK_B_FREQ      = 240_500_240;
  localparam int c_CLK_A_UNCERTAINTY =
    colibri_utils::div_ceil(int'(c_CLK_A_FREQ), int'(c_CLK_REF_FREQ_HZ)) * int'(c_SAMPLE_FREQ_HZ);
  localparam int c_CLK_B_UNCERTAINTY =
    colibri_utils::div_ceil(int'(c_CLK_B_FREQ), int'(c_CLK_REF_FREQ_HZ)) * int'(c_SAMPLE_FREQ_HZ);

  logic clk_ref = 1'b1;
  logic reset   = 1'b1;
  logic clk_a   = 1'b1;
  logic clk_b   = 1'b1;
  logic [c_NUM_CLOCKS-1:0] clk_meas;
  logic [c_DATA_WIDTH-1:0] freq_data [0:c_NUM_CLOCKS-1];
  logic [c_NUM_CLOCKS-1:0] freq_valid;

  int count_a = 0;
  int count_b = 0;
  logic done;

  frequency_counter #(
    .g_CLK_REF_FREQ_HZ(c_CLK_REF_FREQ_HZ),
    .g_NUM_CLOCKS     (c_NUM_CLOCKS),
    .g_DATA_WIDTH     (c_DATA_WIDTH),
    .g_SAMPLE_FREQ_HZ (c_SAMPLE_FREQ_HZ)
  ) dut (
    .clk_ref_i   (clk_ref),
    .reset_i     (reset),
    .clk_meas_i  (clk_meas),
    .freq_data_o (freq_data),
    .freq_valid_o(freq_valid)
  );

  assign clk_meas = {clk_b, clk_a};
  assign done = (count_a > c_THRES) && (count_b > c_THRES);

  // Half periods are picosecond literals. Verilator 5.020 folds a `time`
  // division down to an integer nanosecond, which turns 12.5 ns into 12 ns
  // and 2.079 ns into 2 ns.
  always #5ns clk_ref = ~clk_ref;
  always #12500ps clk_a = ~clk_a;
  always #2079ps clk_b = ~clk_b;

  initial begin : proc_reset
    #(c_CLK_REF_PERIOD * 2);
    @(negedge clk_ref);
    reset = 1'b0;
  end

  initial begin : proc_clk_a
    forever begin
      wait (freq_valid[0] === 1'b1);
      if (count_a > 0) begin
        if (freq_data[0] > (c_CLK_A_FREQ + c_CLK_A_UNCERTAINTY))
          $fatal(1, "CLK A freq too high: got %0d expected %0d uncertainty %0d",
                 freq_data[0], c_CLK_A_FREQ, c_CLK_A_UNCERTAINTY);
        if (freq_data[0] < (c_CLK_A_FREQ - c_CLK_A_UNCERTAINTY))
          $fatal(1, "CLK A freq too low: got %0d expected %0d uncertainty %0d",
                 freq_data[0], c_CLK_A_FREQ, c_CLK_A_UNCERTAINTY);
      end
      count_a = count_a + 1;
      repeat (10) @(posedge clk_ref);
    end
  end

  initial begin : proc_clk_b
    forever begin
      wait (freq_valid[1] === 1'b1);
      if (count_b > 0) begin
        if (freq_data[1] > (c_CLK_B_FREQ + c_CLK_B_UNCERTAINTY))
          $fatal(1, "CLK B freq too high: got %0d expected %0d uncertainty %0d",
                 freq_data[1], c_CLK_B_FREQ, c_CLK_B_UNCERTAINTY);
        if (freq_data[1] < (c_CLK_B_FREQ - c_CLK_B_UNCERTAINTY))
          $fatal(1, "CLK B freq too low: got %0d expected %0d uncertainty %0d",
                 freq_data[1], c_CLK_B_FREQ, c_CLK_B_UNCERTAINTY);
      end
      count_b = count_b + 1;
      repeat (10) @(posedge clk_ref);
    end
  end

  initial begin : proc_main
    wait (reset === 1'b0);
    wait (done === 1'b1);
    $display("PASS frequency_counter_tb a=%0d b=%0d", freq_data[0], freq_data[1]);
    $finish;
  end

  initial begin : proc_watchdog
    #10ms;
    if (!done)
      $fatal(1, "frequency_counter_tb watchdog counts a=%0d b=%0d", count_a, count_b);
  end

endmodule
