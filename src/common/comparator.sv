// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple Comparator.
// Asserts a_gt_b_o when a is greater than b, and only while enable is high.
// g_IS_EQUAL selects a greater-or-equal compare. The result is delayed one cycle.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module comparator #(
  parameter int g_DATA_WIDTH = 32,
  parameter bit g_IS_EQUAL   = 1'b0
) (
  input  logic                    clk_i,
  input  logic                    enable_i,
  input  logic [g_DATA_WIDTH-1:0] a_i,
  input  logic [g_DATA_WIDTH-1:0] b_i,
  output logic                    a_gt_b_o
);

  // a_i and b_i are VHDL unsigned, so the compare stays unsigned.
  always_ff @(posedge clk_i) begin : proc_main
    a_gt_b_o <= 1'b0;
    if (enable_i) begin
      if ((a_i > b_i && !g_IS_EQUAL) || (a_i >= b_i && g_IS_EQUAL))
        a_gt_b_o <= 1'b1;
    end
  end

endmodule
