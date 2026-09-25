// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Broadcasts one Avalon-ST stream to g_NUM_OUTPUTS streams. Each output has
// its own pipeline buffer, and the input fires only when every buffer is ready.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module broadcaster #(
  parameter int unsigned g_NUM_OUTPUTS = 3,
  parameter int unsigned g_DATA_WIDTH  = 32,
  localparam int c_DATA_W  = int'(g_DATA_WIDTH),
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, 8)
) (
  input  logic                         clk_i,
  input  logic                         reset_i,
  input  logic                         snk_sop_i,
  input  logic                         snk_eop_i,
  input  logic                         snk_valid_i,
  output logic                         snk_ready_o,
  input  logic [c_DATA_W-1:0]          snk_data_i,
  input  logic [c_EMPTY_W-1:0]         snk_empty_i,
  output logic [g_NUM_OUTPUTS-1:0]     src_sop_o,
  output logic [g_NUM_OUTPUTS-1:0]     src_eop_o,
  output logic [g_NUM_OUTPUTS-1:0]     src_valid_o,
  input  logic [g_NUM_OUTPUTS-1:0]     src_ready_i,
  output logic [c_DATA_W-1:0]          src_data_o [g_NUM_OUTPUTS-1:0],
  output logic [c_EMPTY_W-1:0]         src_empty_o [g_NUM_OUTPUTS-1:0]
);

  localparam int c_KEEP_W = colibri_utils::downto_width(c_DATA_W / 8);

  logic [g_NUM_OUTPUTS-1:0] int_ready;
  logic                     int_valid;
  logic [c_KEEP_W-1:0]      snk_keep_tie;
  // VHDL leaves pipeline_buffer.src_keep_o open.
  // verilator lint_off UNUSEDSIGNAL
  logic [c_KEEP_W-1:0]      src_keep_unused [0:g_NUM_OUTPUTS-1];
  // verilator lint_on UNUSEDSIGNAL

  assign snk_keep_tie = '0;
  assign snk_ready_o  = &int_ready;
  assign int_valid    = snk_ready_o & snk_valid_i;

  for (genvar i = 0; i < g_NUM_OUTPUTS; i++) begin : gen_buffers
    pipeline_buffer #(
      .g_DATA_WIDTH (g_DATA_WIDTH)
    ) pipeline_buffer_inst (
      .clk_i       (clk_i),
      .reset_i     (reset_i),
      .snk_data_i  (snk_data_i),
      .snk_empty_i (snk_empty_i),
      .snk_keep_i  (snk_keep_tie),
      .snk_sop_i   (snk_sop_i),
      .snk_eop_i   (snk_eop_i),
      .snk_valid_i (int_valid),
      .snk_ready_o (int_ready[i]),
      .src_data_o  (src_data_o[i]),
      .src_empty_o (src_empty_o[i]),
      .src_keep_o  (src_keep_unused[i]),
      .src_sop_o   (src_sop_o[i]),
      .src_eop_o   (src_eop_o[i]),
      .src_valid_o (src_valid_o[i]),
      .src_ready_i (src_ready_i[i])
    );
  end

endmodule
// verilator lint_on MULTITOP
