// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Synchronizes fast pulses over clock domain boundaries.
// Pulses from the source clock become single-cycle pulses in the destination
// domain, independent of the clock-frequency relation. Destination pulses are
// one cycle wide regardless of the source pulse width.
// There should be at least 2 destination clock cycles between consecutive
// source pulses.
//
// Work inspired from the article "Crossing the abyss: asynchronous signals
// in a synchronous world" By Mike Stein, Paradigm Works, available at
// https://www.edn.com/crossing-the-abyss-asynchronous-signals-in-a-synchronous-world/

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module synchro_pulse #(
  parameter int g_NUM_STAGES = 2
) (
  input  logic src_clk_i,
  input  logic dst_clk_i,
  input  logic pulse_i,
  output logic pulse_o
);

  logic pulse_d       = 1'b0;
  logic pulse_edge;
  logic toggle_cmb;
  logic toggle_reg    = 1'b0;
  logic toggle_sync;
  logic toggle_sync_d = 1'b0;

  if (g_NUM_STAGES < 2) begin : gen_stages_check
    $error("ERROR: g_NUM_STAGES must be at least 2");
  end

  // Input rising edge detection (to prevent multiple destination pulses).
  always_ff @(posedge src_clk_i) begin : proc_pulse_d
    pulse_d <= pulse_i;
  end
  assign pulse_edge = pulse_i & ~pulse_d;

  // Toggle circuit in the source domain.
  assign toggle_cmb = pulse_edge ? ~toggle_reg : toggle_reg;
  always_ff @(posedge src_clk_i) begin : proc_toggle
    toggle_reg <= toggle_cmb;
  end

  // Synchronization FF chain for the toggle signal.
  synchro #(
    .g_DATA_LENGTH(1),
    .g_NUM_STAGES(g_NUM_STAGES)
  ) synchro_inst (
    .clk_i(dst_clk_i),
    .reset_i(1'b0),
    .data_i(toggle_reg),
    .data_o(toggle_sync)
  );

  // Any edge detection generates the destination pulse.
  always_ff @(posedge dst_clk_i) begin : proc_toggle_d
    toggle_sync_d <= toggle_sync;
  end
  assign pulse_o = toggle_sync ^ toggle_sync_d;

endmodule
