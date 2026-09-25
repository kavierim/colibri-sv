// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Dual-clock gearbox. Uses cc_fifo, or cc_ram_fifo when g_USE_BLOCK_RAM is set.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module cc_gearbox #(
  parameter int unsigned g_INPUT_WIDTH = 8,
  parameter int unsigned g_OUTPUT_WIDTH = 10,
  parameter int unsigned g_BUFFER_WORDS = 6,
  parameter bit          g_USE_BLOCK_RAM = 1'b0,
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic                      snk_clk_i,
  input  logic                      snk_reset_i,
  input  logic                      src_clk_i,
  input  logic [g_INPUT_WIDTH-1:0]  snk_data_i,
  input  logic                      snk_valid_i,
  output logic                      snk_ready_o,
  output logic [g_OUTPUT_WIDTH-1:0] src_data_o,
  output logic                      src_valid_o,
  input  logic                      src_ready_i
);

  logic fifo_full;
  logic fifo_empty;

  if (g_USE_BLOCK_RAM) begin : gen_ram_fifo
    // VHDL leaves the used-word and empty/full status ports open.
    /* verilator lint_off PINMISSING */
    cc_ram_fifo #(
      .g_NUM_WORDS(g_BUFFER_WORDS),
      .g_INPUT_WIDTH(g_INPUT_WIDTH),
      .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH),
      .g_ENABLE_FWFT(1'b1),
      .g_IMPL_STYLE(g_IMPL_STYLE)
    ) cc_fifo_inst (
      .reset_i(snk_reset_i),
      .wrclk_i(snk_clk_i),
      .rdclk_i(src_clk_i),
      .data_i(snk_data_i),
      .wrreq_i(snk_valid_i),
      .rdreq_i(src_ready_i),
      .q_o(src_data_o),
      .wrfull_o(fifo_full),
      .rdempty_o(fifo_empty)
    );
    /* verilator lint_on PINMISSING */
  end else begin : gen_cc_fifo
    /* verilator lint_off PINMISSING */
    cc_fifo #(
      .g_NUM_WORDS(g_BUFFER_WORDS),
      .g_INPUT_WIDTH(g_INPUT_WIDTH),
      .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH),
      .g_ENABLE_FWFT(1'b1)
    ) cc_fifo_inst (
      .reset_i(snk_reset_i),
      .wrclk_i(snk_clk_i),
      .rdclk_i(src_clk_i),
      .data_i(snk_data_i),
      .wrreq_i(snk_valid_i),
      .rdreq_i(src_ready_i),
      .q_o(src_data_o),
      .wrfull_o(fifo_full),
      .rdempty_o(fifo_empty)
    );
    /* verilator lint_on PINMISSING */
  end

  assign snk_ready_o = ~fifo_full;
  assign src_valid_o = ~fifo_empty;

endmodule
