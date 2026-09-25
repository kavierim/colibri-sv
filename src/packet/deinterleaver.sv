// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Deinterleaves one Avalon-ST stream into g_NUM_OUTPUTS streams using the
// sideband identifier snk_channel_i.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module deinterleaver #(
  parameter int unsigned g_NUM_OUTPUTS = 3,
  parameter int unsigned g_DATA_WIDTH  = 32,
  localparam int c_DATA_W  = int'(g_DATA_WIDTH),
  localparam int c_CH_W    = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_OUTPUTS))),
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
  input  logic [c_CH_W-1:0]            snk_channel_i,
  output logic [g_NUM_OUTPUTS-1:0]     src_sop_o,
  output logic [g_NUM_OUTPUTS-1:0]     src_eop_o,
  output logic [g_NUM_OUTPUTS-1:0]     src_valid_o,
  input  logic [g_NUM_OUTPUTS-1:0]     src_ready_i,
  output logic [c_DATA_W-1:0]          src_data_o [g_NUM_OUTPUTS-1:0],
  output logic [c_EMPTY_W-1:0]         src_empty_o [g_NUM_OUTPUTS-1:0]
);

  localparam int c_PIPE_W      = c_DATA_W + c_CH_W;
  localparam int c_PIPE_KEEP_W = colibri_utils::downto_width(c_PIPE_W / 8);

  logic                     int_sop;
  logic                     int_eop;
  logic                     int_valid;
  logic                     int_ready;
  logic [c_PIPE_W-1:0]      int_data;
  logic [c_EMPTY_W-1:0]     int_empty;
  logic [c_PIPE_KEEP_W-1:0] snk_keep_tie;
  // VHDL leaves pipeline_buffer.src_keep_o open.
  // verilator lint_off UNUSEDSIGNAL
  logic [c_PIPE_KEEP_W-1:0] src_keep_unused;
  // verilator lint_on UNUSEDSIGNAL

  assign snk_keep_tie = '0;

  pipeline_buffer #(
    .g_DATA_WIDTH (c_PIPE_W)
  ) pipeline_buffer_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .snk_data_i  ({snk_channel_i, snk_data_i}),
    .snk_empty_i (snk_empty_i),
    .snk_keep_i  (snk_keep_tie),
    .snk_sop_i   (snk_sop_i),
    .snk_eop_i   (snk_eop_i),
    .snk_valid_i (snk_valid_i),
    .snk_ready_o (snk_ready_o),
    .src_data_o  (int_data),
    .src_empty_o (int_empty),
    .src_keep_o  (src_keep_unused),
    .src_sop_o   (int_sop),
    .src_eop_o   (int_eop),
    .src_valid_o (int_valid),
    .src_ready_i (int_ready)
  );

  // Constant output index. A variable write of src_data_o is dropped
  // by Verilator 5.020.
  logic [c_CH_W-1:0] int_channel;
  assign int_channel = int_data[c_PIPE_W-1 -: c_CH_W];

  for (genvar gi = 0; gi < g_NUM_OUTPUTS; gi++) begin : gen_out
    wire hit = int_valid && (int_channel == c_CH_W'(gi));
    assign src_sop_o[gi]   = hit && int_sop;
    assign src_eop_o[gi]   = hit && int_eop;
    assign src_valid_o[gi] = hit;
    assign src_data_o[gi]  = int_data[c_DATA_W-1:0];
    assign src_empty_o[gi] = int_empty;
  end

  always_comb begin : proc_ready
    int_ready = 1'b0;
    for (int i = 0; i < g_NUM_OUTPUTS; i++) begin
      if (int_channel == c_CH_W'(i))
        int_ready = src_ready_i[i];
    end
  end

endmodule
// verilator lint_on MULTITOP
