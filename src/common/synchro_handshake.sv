// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Clock domain boundary synchronizer with handshake.
// Synchronizes a data/valid/ready stream with a two-way handshake.
// Round-trip latency follows g_NUM_STAGES. Minimum latency is 4 clocks for
// valid and 6 clocks for ready. Intended for signals that change infrequently;
// a cc_fifo is the high-throughput alternative.
// VHDL requires g_DATA_WIDTH (no default). Default 1 lets Verilator elaborate this module.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module synchro_handshake #(
  parameter int g_DATA_WIDTH = 1,
  parameter int g_NUM_STAGES = 2
) (
  input  logic                     snk_clk_i,
  input  logic                     src_clk_i,
  // Same reset feeds synchro (sync) and synchro_reset (async), as in the VHDL.
  // verilator lint_off SYNCASYNCNET
  input  logic                     reset_i,
  // verilator lint_on SYNCASYNCNET
  input  logic [g_DATA_WIDTH-1:0]  snk_data_i,
  input  logic                     snk_valid_i,
  output logic                     snk_ready_o,
  output logic [g_DATA_WIDTH-1:0]  src_data_o,
  output logic                     src_valid_o,
  input  logic                     src_ready_i
);

  logic snk_reset;
  logic src_reset;
  logic snk_feedback;
  logic snk_feedforward;
  logic src_feedforward;
  logic int_ready;

  // CDC attributes match the VHDL: altera_attribute on the data regs only,
  // preserve and dont_touch on the data regs and the feedback pair.
  // async_reg is declared in the VHDL and never applied.
  (* preserve, dont_touch,
     altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  logic [g_DATA_WIDTH-1:0] snk_data_reg = '0;

  (* preserve, dont_touch,
     altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  logic [g_DATA_WIDTH-1:0] src_data_reg = '0;

  (* preserve, dont_touch *)
  logic src_feedback = 1'b0;

  (* preserve, dont_touch *)
  logic feedback_reg = 1'b1;

  logic handshake = 1'b0;

  if (g_DATA_WIDTH < 1) begin : gen_width_check
    $error("ERROR: g_DATA_WIDTH must be at least 1");
  end
  if (g_NUM_STAGES < 2) begin : gen_stages_check
    $error("ERROR: g_NUM_STAGES must be at least 2");
  end

  always_ff @(posedge snk_clk_i) begin : proc_snk
    if (snk_reset) begin
      feedback_reg <= 1'b1;
    end else if (snk_ready_o && snk_valid_i) begin
      snk_data_reg <= snk_data_i;
      // Acknowledge that the source is ready.
      feedback_reg <= snk_feedback;
    end
  end

  // Ready when a transition is seen.
  assign snk_ready_o    = snk_feedback ^ feedback_reg;
  // Signal that new sink data has been captured.
  assign snk_feedforward = feedback_reg;

  always_ff @(posedge src_clk_i) begin : proc_src
    if (src_reset) begin
      src_feedback <= 1'b0;
      handshake    <= 1'b1;
      src_valid_o  <= 1'b0;
      src_data_reg <= '0;
    end else begin
      // New data is available and the source register is free.
      if (int_ready && !src_valid_o) begin
        src_valid_o  <= 1'b1;
        src_data_reg <= snk_data_reg;
        // Tell the sink that the source captured the data.
        src_feedback <= ~src_feedback;
      end
      // Acknowledge a read.
      if (src_ready_i && src_valid_o) begin
        src_valid_o <= 1'b0;
        handshake   <= ~handshake;
      end
    end
  end

  assign src_data_o = src_data_reg;
  assign int_ready  = src_feedforward ^ handshake;

  // Sync the feedback signal (source register ready) into the sink domain.
  synchro #(
    .g_DATA_LENGTH(1),
    .g_INIT_VALUE(1'b1),
    .g_NUM_STAGES(g_NUM_STAGES)
  ) sync_feedback_inst (
    .clk_i(snk_clk_i),
    .reset_i(reset_i),
    .data_i(src_feedback),
    .data_o(snk_feedback)
  );

  // Sync the feedforward signal (sink has new data) into the source domain.
  synchro #(
    .g_DATA_LENGTH(1),
    .g_INIT_VALUE(1'b1),
    .g_NUM_STAGES(g_NUM_STAGES)
  ) sync_feedforward_inst (
    .clk_i(src_clk_i),
    .reset_i(reset_i),
    .data_i(snk_feedforward),
    .data_o(src_feedforward)
  );

  synchro_reset snk_reset_inst (
    .clk_i(snk_clk_i),
    .reset_i(reset_i),
    .reset_o(snk_reset)
  );

  synchro_reset src_reset_inst (
    .clk_i(src_clk_i),
    .reset_i(reset_i),
    .reset_o(src_reset)
  );

endmodule
