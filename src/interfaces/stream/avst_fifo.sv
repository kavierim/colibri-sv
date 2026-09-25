// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Avalon-ST FIFO.
// Buffers every Avalon-ST signal in parallel. Sink and source clocks may be
// synchronous or asynchronous; asynchronous clocks select the clock-crossing FIFO.

`timescale 1ns/1ps

module avst_fifo #(
  parameter int unsigned g_SYM_WIDTH    = 8,
  parameter int unsigned g_DATA_SYM     = 16,
  parameter int unsigned g_NUM_BEATS    = 4,
  parameter bit          g_ASYNC_CLOCKS = 1'b0,
  localparam int c_DATA_WIDTH  = int'(g_DATA_SYM) * int'(g_SYM_WIDTH),
  localparam int c_EMPTY_WIDTH = colibri_types::avst_empty_width(c_DATA_WIDTH, int'(g_SYM_WIDTH)),
  localparam int c_FIFO_WIDTH  = c_DATA_WIDTH + c_EMPTY_WIDTH + 2
) (
  input  logic                      snk_clk_i,
  input  logic                      src_clk_i,
  input  logic                      snk_reset_i,
  output logic                      snk_ready_o,
  input  logic                      snk_valid_i,
  input  logic                      snk_sop_i,
  input  logic                      snk_eop_i,
  input  logic [c_EMPTY_WIDTH-1:0]  snk_empty_i,
  input  logic [c_DATA_WIDTH-1:0]   snk_data_i,
  input  logic                      src_ready_i,
  output logic                      src_valid_o,
  output logic                      src_sop_o,
  output logic                      src_eop_o,
  output logic [c_EMPTY_WIDTH-1:0]  src_empty_o,
  output logic [c_DATA_WIDTH-1:0]   src_data_o
);

  logic [c_FIFO_WIDTH-1:0] fifo_in;
  logic [c_FIFO_WIDTH-1:0] fifo_out;
  logic                    fifo_full;
  logic                    fifo_empty;

  // Status and queue-echo ports are unused by the stream wrapper.
  // verilator lint_off PINMISSING
  if (g_ASYNC_CLOCKS) begin : gen_async_fifo
    cc_fifo #(
      .g_NUM_WORDS   (g_NUM_BEATS),
      .g_INPUT_WIDTH (c_FIFO_WIDTH),
      .g_ENABLE_FWFT (1'b1)
    ) cc_fifo_inst (
      .reset_i   (snk_reset_i),
      .wrclk_i   (snk_clk_i),
      .rdclk_i   (src_clk_i),
      .data_i    (fifo_in),
      .wrreq_i   (snk_valid_i),
      .rdreq_i   (src_ready_i),
      .q_o       (fifo_out),
      .wrfull_o  (fifo_full),
      .rdempty_o (fifo_empty)
    );
  end else begin : gen_sync_fifo
    fifo #(
      .g_NUM_WORDS   (g_NUM_BEATS),
      .g_INPUT_WIDTH (c_FIFO_WIDTH),
      .g_ENABLE_FWFT (1'b1)
    ) fifo_inst (
      .clk_i   (snk_clk_i),
      .reset_i (snk_reset_i),
      .data_i  (fifo_in),
      .wrreq_i (snk_valid_i),
      .rdreq_i (src_ready_i),
      .q_o     (fifo_out),
      .empty_o (fifo_empty),
      .full_o  (fifo_full)
    );
  end
  // verilator lint_on PINMISSING

  assign fifo_in     = {snk_sop_i, snk_eop_i, snk_empty_i, snk_data_i};
  assign snk_ready_o = ~(fifo_full | snk_reset_i);

  // src_clk_i is an entity port. The synchronous FIFO does not read it.
  // verilator lint_off UNUSEDSIGNAL
  logic unused_src_clk;
  assign unused_src_clk = src_clk_i;
  // verilator lint_on UNUSEDSIGNAL

  always_comb begin : proc_src
    src_valid_o = ~fifo_empty;
    if (fifo_empty) begin
      src_sop_o   = 1'b0;
      src_eop_o   = 1'b0;
      src_empty_o = '0;
      src_data_o  = '0;
    end else begin
      src_sop_o   = fifo_out[c_FIFO_WIDTH-1];
      src_eop_o   = fifo_out[c_FIFO_WIDTH-2];
      src_empty_o = fifo_out[c_DATA_WIDTH +: c_EMPTY_WIDTH];
      src_data_o  = fifo_out[c_DATA_WIDTH-1:0];
    end
  end

endmodule
