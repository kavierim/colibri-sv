// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit edge_detect_vu. prev_valid is local to the vunit.
module edge_detect_sva #(
  parameter logic g_RESET_VAL = 1'b0
) (
  input logic clk_i,
  input logic data_i,
  input logic pulse_o
);

  logic prev_valid = 1'b0;

  always_ff @(posedge clk_i) begin
    prev_valid <= 1'b1;
  end

  // {data = reset; data /= reset} |-> pulse /= reset
  // $past stands in for a one-cycle sequence delay.
  t_valid_pulse: assert property (@(posedge clk_i)
    ($past(data_i) == g_RESET_VAL) && (data_i != g_RESET_VAL) |-> (pulse_o != g_RESET_VAL));

  // {data /= reset; data = reset} |-> pulse = reset
  t_no_pulse_edge: assert property (@(posedge clk_i)
    ($past(data_i) != g_RESET_VAL) && (data_i == g_RESET_VAL) |-> (pulse_o == g_RESET_VAL));

  // Stable input does not pulse, once a previous sample exists.
  t_no_pulse_stable: assert property (@(posedge clk_i)
    prev_valid && $stable(data_i) |-> (pulse_o == g_RESET_VAL));

endmodule

bind edge_detect edge_detect_sva #(
  .g_RESET_VAL(g_RESET_VAL)
) u_edge_detect_sva (
  .clk_i(clk_i),
  .data_i(data_i),
  .pulse_o(pulse_o)
);
