// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Edge detect.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module edge_detect #(
  parameter logic g_RESET_VAL = 1'b0
) (
  input  logic clk_i,
  input  logic data_i,
  output logic pulse_o
);

  logic data_reg;

  always_ff @(posedge clk_i) begin : proc_reg
    data_reg <= data_i;
  end

  assign pulse_o = ((data_i != data_reg) && (data_i != g_RESET_VAL)) ? data_i : g_RESET_VAL;

endmodule
