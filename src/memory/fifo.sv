// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Single-clock FIFO. The shared-variable memory is a logic array updated in always_ff.
// Mixed input/output widths instantiate gearbox (src/comms).

`timescale 1ns/1ps

module fifo #(
  parameter int g_NUM_WORDS    = 4,
  parameter int g_INPUT_WIDTH  = 8,
  parameter int g_OUTPUT_WIDTH = g_INPUT_WIDTH,
  parameter bit g_ENABLE_FWFT  = 1'b0
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [g_INPUT_WIDTH-1:0] data_i,
  input  logic wrreq_i,
  input  logic rdreq_i,
  output logic [g_OUTPUT_WIDTH-1:0] q_o,
  output logic [colibri_utils::log2ceil(g_NUM_WORDS):0] usedw_o,
  output logic empty_o,
  output logic full_o
);

  localparam int c_FIFO_WIDTH = colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH);
  localparam int c_USEDW_W    = colibri_utils::log2ceil(g_NUM_WORDS) + 1;

  logic [c_FIFO_WIDTH-1:0] memory [0:g_NUM_WORDS-1];

  logic [c_FIFO_WIDTH-1:0] data_in;
  logic wrreq;
  logic full;
  logic [c_FIFO_WIDTH-1:0] data_out;
  logic rdreq;
  logic empty;
  // PSL fifo.psl reads these pointers from the bound checker.
  int wr_ptr /* verilator public */;
  int rd_ptr /* verilator public */;
  int int_usedw;
  logic wr_safe;
  logic rd_safe;
  logic int_rdreq;
  logic int_empty;

  initial begin
    wr_ptr    = 0;
    rd_ptr    = 0;
    int_usedw = 0;
  end

  if (g_INPUT_WIDTH < g_OUTPUT_WIDTH) begin : gen_up_conversion
    logic gbx_ready;
    gearbox #(
      .g_INPUT_WIDTH(g_INPUT_WIDTH),
      .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH)
    ) gearbox_inst (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .snk_data_i(data_i),
      .snk_valid_i(wrreq_i),
      .snk_ready_o(gbx_ready),
      .src_data_o(data_in),
      .src_valid_o(wrreq),
      .src_ready_i(~full)
    );
    assign full_o = ~gbx_ready;
  end else begin : gen_up_passthrough
    assign data_in = data_i;
    assign wrreq   = wrreq_i;
    assign full_o  = full;
  end

  assign wr_safe = wrreq & ~full;

  always_ff @(posedge clk_i) begin : proc_used_words
    if (reset_i)
      int_usedw <= 0;
    else if (wr_safe && !rd_safe)
      int_usedw <= int_usedw + 1;
    else if (!wr_safe && rd_safe)
      int_usedw <= int_usedw - 1;
  end

  assign usedw_o   = c_USEDW_W'(int_usedw);
  assign full      = (int_usedw == g_NUM_WORDS);
  assign int_empty = (int_usedw == 0);

  always_ff @(posedge clk_i) begin : proc_write_ptr
    if (reset_i)
      wr_ptr <= 0;
    else if (wr_safe) begin
      if (wr_ptr == (g_NUM_WORDS - 1))
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1;
    end
  end

  always_ff @(posedge clk_i) begin : proc_read_ptr
    if (reset_i)
      rd_ptr <= 0;
    else if (rd_safe) begin
      if (rd_ptr == (g_NUM_WORDS - 1))
        rd_ptr <= 0;
      else
        rd_ptr <= rd_ptr + 1;
    end
  end

  // VHDL updates the shared memory variable before the same-edge read, so a
  // same-address read-during-write returns the new word. Full and empty still
  // gate wr_safe and rd_safe; this path is the FWFT prefetch of an empty FIFO.
  always_ff @(posedge clk_i) begin : proc_memory
    if (!reset_i && wr_safe)
      memory[wr_ptr] <= data_in;
    if (!reset_i && rd_safe) begin
      if (wr_safe && (wr_ptr == rd_ptr))
        data_out <= data_in;
      else
        data_out <= memory[rd_ptr];
    end
  end

  if (g_ENABLE_FWFT || (g_INPUT_WIDTH > g_OUTPUT_WIDTH)) begin : gen_stream_fifo
    logic reg_valid;
    logic cmb_valid;
    initial reg_valid = 1'b0;

    always_comb begin : proc_fifo_stream_cmb
      logic v_valid;
      v_valid = reg_valid;
      if (rdreq && reg_valid)
        v_valid = 1'b0;
      if ((!int_empty || wrreq) && !v_valid) begin
        int_rdreq = 1'b1;
        v_valid   = 1'b1;
      end else begin
        int_rdreq = 1'b0;
      end
      if (reset_i)
        v_valid = 1'b0;
      cmb_valid = v_valid;
    end

    always_ff @(posedge clk_i) begin : proc_reg_valid
      reg_valid <= cmb_valid;
    end

    assign empty   = ~reg_valid;
    assign rd_safe = int_rdreq;
  end else begin : gen_no_stream
    assign int_rdreq = rdreq;
    assign empty     = int_empty;
    assign rd_safe   = int_rdreq & ~int_empty;
  end

  if (g_INPUT_WIDTH > g_OUTPUT_WIDTH) begin : gen_down_conversion
    logic gbx_valid;
    logic [g_OUTPUT_WIDTH-1:0] gbx_data_out;
    gearbox #(
      .g_INPUT_WIDTH(g_INPUT_WIDTH),
      .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH)
    ) gearbox_inst (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .snk_data_i(data_out),
      .snk_valid_i(~empty),
      .snk_ready_o(rdreq),
      .src_data_o(gbx_data_out),
      .src_valid_o(gbx_valid),
      .src_ready_i(rdreq_i)
    );
    assign empty_o = ~gbx_valid;
    if (g_ENABLE_FWFT) begin : gen_output_delay
      assign q_o = gbx_data_out;
    end else begin : gen_output_reg
      always_ff @(posedge clk_i) begin : proc_output_delay
        q_o <= gbx_data_out;
      end
    end
  end else begin : gen_down_passthrough
    assign q_o     = data_out;
    assign empty_o = empty;
    assign rdreq   = rdreq_i;
  end

endmodule
