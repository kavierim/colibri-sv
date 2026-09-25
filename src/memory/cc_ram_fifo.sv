// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Dual-clock FIFO built around simple_dpram.
// g_NUM_WORDS and g_INPUT_WIDTH have elaboration defaults; the VHDL generics do not.
// Reset and pointer crossing use synchro_reset and synchro (src/common).

`timescale 1ns/1ps

module cc_ram_fifo #(
  parameter int g_NUM_WORDS    = 4,
  parameter int g_INPUT_WIDTH  = 8,
  parameter int g_OUTPUT_WIDTH = g_INPUT_WIDTH,
  parameter bit g_ENABLE_FWFT  = 1'b0,
  parameter int g_INPUT_USEDW_WIDTH = colibri_utils::log2ceil(
    colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH) * g_NUM_WORDS / g_INPUT_WIDTH
  ),
  parameter int g_OUTPUT_USEDW_WIDTH = colibri_utils::log2ceil(
    colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH) * g_NUM_WORDS / g_OUTPUT_WIDTH
  ),
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic reset_i,
  input  logic wrclk_i,
  input  logic [g_INPUT_WIDTH-1:0] data_i,
  input  logic wrreq_i,
  output logic [colibri_utils::downto_width(g_INPUT_USEDW_WIDTH)-1:0] wrusedw_o,
  output logic wrempty_o,
  output logic wrfull_o,
  input  logic rdclk_i,
  input  logic rdreq_i,
  output logic [g_OUTPUT_WIDTH-1:0] q_o,
  output logic [colibri_utils::downto_width(g_OUTPUT_USEDW_WIDTH)-1:0] rdusedw_o,
  output logic rdempty_o,
  output logic rdfull_o
);

  localparam int c_MEM_WIDTH = colibri_utils::minimum(g_INPUT_WIDTH, g_OUTPUT_WIDTH);
  localparam int c_MEM_DEPTH = colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH) / c_MEM_WIDTH * g_NUM_WORDS;
  localparam int c_WR_RATIO  = g_INPUT_WIDTH / c_MEM_WIDTH;
  localparam int c_RD_RATIO  = g_OUTPUT_WIDTH / c_MEM_WIDTH;
  localparam int c_WR_WORDS  = c_MEM_DEPTH / c_WR_RATIO;
  localparam int c_RD_WORDS  = c_MEM_DEPTH / c_RD_RATIO;
  localparam int c_WR_PTR_W  = colibri_utils::downto_width(colibri_utils::log2ceil(c_WR_WORDS));
  localparam int c_RD_PTR_W  = colibri_utils::downto_width(colibri_utils::log2ceil(c_RD_WORDS));
  localparam int c_WR_USED_W = colibri_utils::downto_width(g_INPUT_USEDW_WIDTH);
  localparam int c_RD_USED_W = colibri_utils::downto_width(g_OUTPUT_USEDW_WIDTH);

  logic [g_INPUT_WIDTH-1:0] data_in;
  logic wrreq;
  logic wrfull;
  int wr_ptr;
  int wrd_ptr;
  logic [c_WR_PTR_W-1:0] wr_ptr_gray;
  logic [c_RD_PTR_W-1:0] wrd_ptr_gray;
  int int_wusedw;

  logic [g_OUTPUT_WIDTH-1:0] data_out;
  logic rdreq;
  logic rdempty;
  int rd_ptr;
  int rwr_ptr;
  logic [c_RD_PTR_W-1:0] rd_ptr_gray;
  logic [c_WR_PTR_W-1:0] rwr_ptr_gray;
  int int_rusedw;

  logic wr_safe;
  logic rd_safe;
  logic int_empty;
  logic int_rdreq;
  logic wr_reset;
  logic rd_reset;

  initial begin
    wr_ptr = 0;
    rd_ptr = 0;
  end

  synchro_reset #(
    .g_IN_POLARITY(1'b1),
    .g_OUT_POLARITY(1'b1),
    .g_DURATION(1)
  ) wr_synchro_reset (
    .clk_i(wrclk_i),
    .reset_i(reset_i),
    .reset_o(wr_reset)
  );

  synchro_reset #(
    .g_IN_POLARITY(1'b1),
    .g_OUT_POLARITY(1'b1),
    .g_DURATION(1)
  ) rd_synchro_reset (
    .clk_i(rdclk_i),
    .reset_i(reset_i),
    .reset_o(rd_reset)
  );

  assign data_in  = data_i;
  assign wrreq    = wrreq_i;
  assign wrfull_o = wrfull | wr_reset;

  assign wr_safe = wrreq & ~wrfull;
  assign rd_safe = int_rdreq & ~int_empty;

  always_ff @(posedge wrclk_i) begin : proc_wr_ptr_gray
    wr_ptr_gray <= colibri_encoders::enc#(c_WR_PTR_W)::bin2gray_nat(wr_ptr);
  end

  always_ff @(posedge rdclk_i) begin : proc_rd_ptr_gray
    rd_ptr_gray <= colibri_encoders::enc#(c_RD_PTR_W)::bin2gray_nat(rd_ptr);
  end

  assign rwr_ptr = colibri_encoders::enc#(c_WR_PTR_W)::gray2bin_nat(rwr_ptr_gray) * c_WR_RATIO / c_RD_RATIO;
  assign wrd_ptr = colibri_encoders::enc#(c_RD_PTR_W)::gray2bin_nat(wrd_ptr_gray) * c_RD_RATIO / c_WR_RATIO;

  synchro #(
    .g_DATA_LENGTH(c_WR_PTR_W),
    .g_NUM_STAGES(2)
  ) wr_ptr_synchro (
    .clk_i(rdclk_i),
    .reset_i(rd_reset),
    .data_i(wr_ptr_gray),
    .data_o(rwr_ptr_gray)
  );

  synchro #(
    .g_DATA_LENGTH(c_RD_PTR_W),
    .g_NUM_STAGES(2)
  ) rd_ptr_synchro (
    .clk_i(wrclk_i),
    .reset_i(wr_reset),
    .data_i(rd_ptr_gray),
    .data_o(wrd_ptr_gray)
  );

  assign int_wusedw = (wr_ptr < wrd_ptr) ? (c_WR_WORDS + wr_ptr - wrd_ptr) : (wr_ptr - wrd_ptr);
  assign wrusedw_o  = c_WR_USED_W'(int_wusedw);
  assign int_rusedw = (rwr_ptr < rd_ptr) ? (c_RD_WORDS + rwr_ptr - rd_ptr) : (rwr_ptr - rd_ptr);
  assign rdusedw_o  = c_RD_USED_W'(int_rusedw);

  assign wrfull    = (int_wusedw == (c_WR_WORDS - 1));
  assign wrempty_o = (int_wusedw == 0);
  assign rdfull_o  = (int_rusedw == (c_RD_WORDS - 1));
  assign int_empty = (int_rusedw == 0);

  always_ff @(posedge wrclk_i) begin : proc_wr_ptr
    if (wr_reset)
      wr_ptr <= 0;
    else if (wr_safe) begin
      if (wr_ptr == (c_WR_WORDS - 1))
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1;
    end
  end

  always_ff @(posedge rdclk_i) begin : proc_rd_ptr
    if (rd_reset)
      rd_ptr <= 0;
    else if (rd_safe) begin
      if (rd_ptr == (c_RD_WORDS - 1))
        rd_ptr <= 0;
      else
        rd_ptr <= rd_ptr + 1;
    end
  end

  simple_dpram #(
    .g_A_DATA_WIDTH(g_INPUT_WIDTH),
    .g_B_DATA_WIDTH(g_OUTPUT_WIDTH),
    .g_N_WORDS(g_NUM_WORDS),
    .g_A_ADDR_WIDTH(c_WR_PTR_W),
    .g_B_ADDR_WIDTH(c_RD_PTR_W),
    .g_IMPL_STYLE(g_IMPL_STYLE)
  ) fifo_ram_inst (
    .wrclk_i(wrclk_i),
    .wren_i(wr_safe & ~wr_reset),
    .wraddr_i(c_WR_PTR_W'(wr_ptr)),
    .wrdata_i(data_in),
    .rdclk_i(rdclk_i),
    .rden_i(rd_safe & ~rd_reset),
    .rdaddr_i(c_RD_PTR_W'(rd_ptr)),
    .rddata_o(data_out)
  );

  if (g_ENABLE_FWFT) begin : gen_stream_fifo
    logic reg_valid;
    logic cmb_valid;
    initial reg_valid = 1'b0;

    always_comb begin : proc_fifo_stream_cmb
      logic v_valid;
      v_valid = reg_valid;
      if (rdreq && reg_valid)
        v_valid = 1'b0;
      if (!int_empty && !v_valid) begin
        int_rdreq = 1'b1;
        v_valid   = 1'b1;
      end else begin
        int_rdreq = 1'b0;
      end
      if (rd_reset)
        v_valid = 1'b0;
      cmb_valid = v_valid;
    end

    always_ff @(posedge rdclk_i) begin : proc_reg_valid
      reg_valid <= cmb_valid;
    end

    assign rdempty = ~reg_valid;
  end else begin : gen_no_stream
    assign int_rdreq = rdreq;
    assign rdempty   = int_empty;
  end

  assign q_o       = data_out;
  assign rdempty_o = rdempty;
  assign rdreq     = rdreq_i;

endmodule
