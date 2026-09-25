// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// CDC Streaming Upsizing Gearbox.
// Generic upscaling gearbox for continuous streams with a clock domain crossing.
// It includes a slip signal to shift the output (1 bit resolution).
// Based on gearbox_up and cc_fifo.
// Release log:
// - 0.1: initial release

`timescale 1ns/1ps

module cc_gearbox_up #(
  parameter int unsigned g_INPUT_WIDTH  = 8,
  parameter int unsigned g_OUTPUT_WIDTH = 10,
  parameter int unsigned g_BUFFER_WORDS = 6
) (
  input  logic                          snk_clk_i,
  input  logic                          snk_reset_i,
  input  logic                          src_clk_i,
  input  logic                          slip_i,
  input  logic [g_INPUT_WIDTH-1:0]      snk_data_i,
  input  logic                          snk_valid_i,
  output logic [g_OUTPUT_WIDTH-1:0]     src_data_o,
  output logic                          src_valid_o
);

  logic wr_slip;
  logic wr_reset;
  // Driven by the read-domain reset synchronizer and never read, as in the VHDL.
  // verilator lint_off UNUSEDSIGNAL
  logic rd_reset;
  logic fifo_full;
  // verilator lint_on UNUSEDSIGNAL
  logic [g_OUTPUT_WIDTH-1:0] gbx_data;
  logic gbx_valid;
  logic fifo_empty;

  // synchronize reset_i to the write domain
  synchro_reset #(
    .g_IN_POLARITY(1'b1),
    .g_OUT_POLARITY(1'b1),
    .g_DURATION(1)
  ) wr_synchro_reset (
    .clk_i(snk_clk_i),
    .reset_i(snk_reset_i),
    .reset_o(wr_reset)
  );

  // synchronize reset_i to the read domain
  synchro_reset #(
    .g_IN_POLARITY(1'b1),
    .g_OUT_POLARITY(1'b1),
    .g_DURATION(1)
  ) rd_synchro_reset (
    .clk_i(src_clk_i),
    .reset_i(snk_reset_i),
    .reset_o(rd_reset)
  );

  // synchronize slip_i to the write domain
  synchro_pulse wr_synchro_slip (
    .src_clk_i(src_clk_i),
    .dst_clk_i(snk_clk_i),
    .pulse_i(slip_i),
    .pulse_o(wr_slip)
  );

  gearbox_up #(
    .g_INPUT_WIDTH(int'(g_INPUT_WIDTH)),
    .g_OUTPUT_WIDTH(int'(g_OUTPUT_WIDTH))
  ) gearbox_inst (
    .clk_i(snk_clk_i),
    .reset_i(wr_reset),
    .slip_i(wr_slip),
    .snk_data_i(snk_data_i),
    .snk_valid_i(snk_valid_i),
    .src_data_o(gbx_data),
    .src_valid_o(gbx_valid)
  );

  // VHDL leaves the used-word and write-side status ports open.
  // verilator lint_off PINMISSING
  cc_fifo #(
    .g_NUM_WORDS(int'(g_BUFFER_WORDS)),
    .g_INPUT_WIDTH(int'(g_OUTPUT_WIDTH)),
    .g_OUTPUT_WIDTH(int'(g_OUTPUT_WIDTH)),
    .g_ENABLE_FWFT(1'b1)
  ) cc_fifo_inst (
    .reset_i(snk_reset_i),
    .wrclk_i(snk_clk_i),
    .rdclk_i(src_clk_i),
    .data_i(gbx_data),
    .wrreq_i(gbx_valid),
    .rdreq_i(1'b1),
    .q_o(src_data_o),
    .wrfull_o(fifo_full),
    .rdempty_o(fifo_empty)
  );
  // verilator lint_on PINMISSING

  assign src_valid_o = ~fifo_empty;

endmodule
