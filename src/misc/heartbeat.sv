// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Clock heartbeat generator. Divides `clk_i` down to `heartbeat_o`.

`timescale 1ns/1ps

module heartbeat #(
  // verilator lint_off REALCVT
  parameter time g_BEAT_PERIOD = 1s,
  parameter time g_CLK_PERIOD  = 8ns
  // verilator lint_on REALCVT
) (
  input  logic clk_i,
  input  logic reset_i,
  output logic heartbeat_o
);

  // Half-period count. VHDL `/` on time truncates, then divides by 2.
  localparam int unsigned c_CNT_MAX = int'((g_BEAT_PERIOD / g_CLK_PERIOD) / 2);

  logic pulse_flip;

  // verilator lint_off PINCONNECTEMPTY
  counter #(
    .g_MODULO(c_CNT_MAX)
  ) counter_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .enable_i    (1'b1),
    .value_o     (),
    .wraparound_o(pulse_flip)
  );
  // verilator lint_on PINCONNECTEMPTY

  always_ff @(posedge clk_i) begin : proc_out_driver
    if (reset_i)
      heartbeat_o <= 1'b0;
    else if (pulse_flip)
      heartbeat_o <= ~heartbeat_o;
  end

endmodule
