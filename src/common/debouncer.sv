// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Debouncer.
// Release log:
// - 0.1 first release
//
// g_RESET_VAL is an unconstrained std_logic_vector in VHDL. data_i and data_o
// take $bits(g_RESET_VAL); pass a sized vector. g_CLOCK_PERIOD has no VHDL
// default; 10 ns is only so Verilator can elaborate this module.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module debouncer #(
  parameter g_RESET_VAL              = 1'b0,
  parameter time g_DEBOUNCE_TIME     = 10ms,
  parameter time g_CLOCK_PERIOD      = 10ns
) (
  input  logic                          clk_i,
  input  logic                          reset_i,
  input  logic [$bits(g_RESET_VAL)-1:0] data_i,
  output logic [$bits(g_RESET_VAL)-1:0] data_o
);

  localparam int c_MODULO_DEBOUNCE = colibri_utils::div_ceil_time(g_DEBOUNCE_TIME, g_CLOCK_PERIOD);
  localparam int c_CNT_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_MODULO_DEBOUNCE));

  logic                          cnt_reset;
  logic                          valid;
  logic [$bits(g_RESET_VAL)-1:0] data_reg;

  // value_o is left open in the VHDL instantiation.
  // verilator lint_off UNUSEDSIGNAL
  logic [c_CNT_W-1:0] value_unused;
  // verilator lint_on UNUSEDSIGNAL

  counter #(
    .g_MODULO(c_MODULO_DEBOUNCE)
  ) counter_inst (
    .clk_i(clk_i),
    .reset_i(cnt_reset),
    .enable_i(1'b1),
    .value_o(value_unused),
    .wraparound_o(valid)
  );

  always_ff @(posedge clk_i) begin : proc_debounce
    if (reset_i) begin
      cnt_reset <= 1'b1;
      data_reg  <= '0;
      data_o    <= g_RESET_VAL;
    end else begin
      cnt_reset <= 1'b0;
      data_reg  <= data_i;
      // If data changes, reset the counter.
      if (data_i != data_reg)
        cnt_reset <= 1'b1;
      else if (valid)
        // Counter expired: accept the input.
        data_o <= data_i;
    end
  end

endmodule
