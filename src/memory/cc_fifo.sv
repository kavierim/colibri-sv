// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Dual-clock FIFO with optional mixed width, FWFT, and write-side peek.
// Reset and pointer crossing use synchro_reset and synchro (src/common).
// Mixed widths use gearbox (src/comms).

`timescale 1ns/1ps

module cc_fifo #(
  parameter int g_NUM_WORDS    = 4,
  parameter int g_INPUT_WIDTH  = 8,
  parameter int g_OUTPUT_WIDTH = g_INPUT_WIDTH,
  parameter bit g_ENABLE_FWFT  = 1'b0,
  parameter bit g_PEEK_NEXT    = 1'b0
) (
  input  logic reset_i,
  input  logic wrclk_i,
  input  logic rdclk_i,
  input  logic [g_INPUT_WIDTH-1:0] data_i,
  input  logic wrreq_i,
  input  logic rdreq_i,
  output logic [g_OUTPUT_WIDTH-1:0] q_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS))-1:0] wrusedw_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS))-1:0] rdusedw_o,
  output logic wrempty_o,
  output logic wrfull_o,
  output logic rdempty_o,
  output logic rdfull_o,
  output logic [g_INPUT_WIDTH-1:0] wrq_o,
  output logic wrq_valid_o
);

  localparam int c_FIFO_WIDTH = colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH);
  localparam int c_PTR_W      = colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS));

  logic [c_FIFO_WIDTH-1:0] memory [0:g_NUM_WORDS-1];

  logic [c_FIFO_WIDTH-1:0] data_in;
  logic wrreq;
  logic wrfull;
  logic [c_FIFO_WIDTH-1:0] data_out;
  logic rdreq;
  logic rdempty;
  int wr_ptr;
  int rd_ptr;
  int rwr_ptr;
  int wrd_ptr;
  logic [c_PTR_W-1:0] wr_ptr_gray;
  logic [c_PTR_W-1:0] rd_ptr_gray;
  logic [c_PTR_W-1:0] rwr_ptr_gray;
  logic [c_PTR_W-1:0] wrd_ptr_gray;
  int int_rusedw;
  int int_wusedw;
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

  if (g_INPUT_WIDTH < g_OUTPUT_WIDTH) begin : gen_up_conversion
    logic gbx_ready;
    gearbox #(
      .g_INPUT_WIDTH(g_INPUT_WIDTH),
      .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH)
    ) gearbox_inst (
      .clk_i(wrclk_i),
      .reset_i(wr_reset),
      .snk_data_i(data_i),
      .snk_valid_i(wrreq_i),
      .snk_ready_o(gbx_ready),
      .src_data_o(data_in),
      .src_valid_o(wrreq),
      .src_ready_i(~wrfull)
    );
    assign wrfull_o = ~gbx_ready;
  end else begin : gen_up_passthrough
    assign data_in  = data_i;
    assign wrreq    = wrreq_i;
    assign wrfull_o = wrfull | wr_reset;
  end

  assign wr_safe = wrreq & ~wrfull;
  assign rd_safe = int_rdreq & ~int_empty;

  always_ff @(posedge wrclk_i) begin : proc_wr_ptr_gray
    wr_ptr_gray <= colibri_encoders::enc#(c_PTR_W)::bin2gray_nat(wr_ptr);
  end

  always_ff @(posedge rdclk_i) begin : proc_rd_ptr_gray
    rd_ptr_gray <= colibri_encoders::enc#(c_PTR_W)::bin2gray_nat(rd_ptr);
  end

  assign rwr_ptr = colibri_encoders::enc#(c_PTR_W)::gray2bin_nat(rwr_ptr_gray);
  assign wrd_ptr = colibri_encoders::enc#(c_PTR_W)::gray2bin_nat(wrd_ptr_gray);

  synchro #(
    .g_DATA_LENGTH(c_PTR_W),
    .g_NUM_STAGES(2)
  ) wr_ptr_synchro (
    .clk_i(rdclk_i),
    .reset_i(rd_reset),
    .data_i(wr_ptr_gray),
    .data_o(rwr_ptr_gray)
  );

  synchro #(
    .g_DATA_LENGTH(c_PTR_W),
    .g_NUM_STAGES(2)
  ) rd_ptr_synchro (
    .clk_i(wrclk_i),
    .reset_i(wr_reset),
    .data_i(rd_ptr_gray),
    .data_o(wrd_ptr_gray)
  );

  assign int_wusedw = (wr_ptr < wrd_ptr) ? (g_NUM_WORDS + wr_ptr - wrd_ptr) : (wr_ptr - wrd_ptr);
  assign wrusedw_o  = c_PTR_W'(int_wusedw);
  assign int_rusedw = (rwr_ptr < rd_ptr) ? (g_NUM_WORDS + rwr_ptr - rd_ptr) : (rwr_ptr - rd_ptr);
  assign rdusedw_o  = c_PTR_W'(int_rusedw);

  assign wrfull    = (int_wusedw == (g_NUM_WORDS - 1));
  assign rdfull_o  = (int_rusedw == (g_NUM_WORDS - 1));
  assign int_empty = (int_rusedw == 0);

  synchro #(
    .g_DATA_LENGTH(1),
    .g_INIT_VALUE(1'b1),
    .g_NUM_STAGES(2)
  ) empty_sync_inst (
    .clk_i(wrclk_i),
    .reset_i(wr_reset),
    .data_i(rdempty_o),
    .data_o(wrempty_o)
  );

  always_ff @(posedge wrclk_i) begin : proc_wr_ptr
    if (wr_reset)
      wr_ptr <= 0;
    else if (wr_safe) begin
      if (wr_ptr == (g_NUM_WORDS - 1))
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1;
    end
  end

  always_ff @(posedge rdclk_i) begin : proc_rd_ptr
    if (rd_reset)
      rd_ptr <= 0;
    else if (rd_safe) begin
      if (rd_ptr == (g_NUM_WORDS - 1))
        rd_ptr <= 0;
      else
        rd_ptr <= rd_ptr + 1;
    end
  end

  always_ff @(posedge wrclk_i) begin : proc_data_write
    if (!wr_reset && wr_safe)
      memory[wr_ptr] <= data_in;
  end

  always_ff @(posedge rdclk_i) begin : proc_data_read
    if (!rd_reset && rd_safe)
      data_out <= memory[rd_ptr];
  end

  if (g_PEEK_NEXT && (g_INPUT_WIDTH == g_OUTPUT_WIDTH)) begin : gen_peek_write
    // Separate signals, not a struct: identical specializations inlined into
    // several parents otherwise emit the same C++ struct name.
    int peek_ptr;
    logic peek_enable;
    logic [g_INPUT_WIDTH-1:0] peek_q;
    logic [g_INPUT_WIDTH-1:0] peek_fwft;
    logic peek_valid;
    int peek_ptr_c;
    logic peek_enable_c;
    logic [g_INPUT_WIDTH-1:0] peek_q_c;
    logic [g_INPUT_WIDTH-1:0] peek_fwft_c;
    logic peek_valid_c;

    initial begin
      peek_ptr    = 0;
      peek_enable = 1'b0;
      peek_q      = '0;
      peek_fwft   = '0;
      peek_valid  = 1'b0;
    end

    always_comb begin : proc_peek_logic
      peek_ptr_c    = wrd_ptr;
      peek_enable_c = peek_enable;
      peek_q_c      = peek_q;
      peek_fwft_c   = peek_fwft;
      peek_valid_c  = peek_valid;
      if ((peek_ptr != wrd_ptr) && (wr_ptr != wrd_ptr)) begin
        peek_valid_c = 1'b1;
        peek_q_c     = memory[wrd_ptr];
      end else if ((int_wusedw == 0) && wr_safe) begin
        peek_valid_c = 1'b1;
        peek_q_c     = data_i;
      end else begin
        peek_valid_c = 1'b0;
      end
      if (g_ENABLE_FWFT) begin
        if (peek_valid) begin
          peek_fwft_c   = peek_q;
          peek_enable_c = 1'b1;
        end
      end
      if (wr_reset) begin
        peek_ptr_c    = 0;
        peek_enable_c = 1'b0;
        peek_q_c      = '0;
        peek_fwft_c   = '0;
        peek_valid_c  = 1'b0;
      end
    end

    always_ff @(posedge wrclk_i) begin : proc_peek_reg
      peek_ptr    <= peek_ptr_c;
      peek_enable <= peek_enable_c;
      peek_q      <= peek_q_c;
      peek_fwft   <= peek_fwft_c;
      peek_valid  <= peek_valid_c;
    end

    if (g_ENABLE_FWFT) begin : gen_fwft
      always_ff @(posedge wrclk_i) begin : proc_fwft
        if (peek_valid) begin
          wrq_valid_o <= peek_enable;
          wrq_o       <= peek_fwft;
        end else begin
          wrq_valid_o <= 1'b0;
          wrq_o       <= '0;
        end
      end
    end else begin : gen_fwft_comb
      assign wrq_valid_o = peek_valid;
      assign wrq_o       = peek_q;
    end
  end else begin : gen_no_peek
    assign wrq_o       = '0;
    assign wrq_valid_o = 1'b0;
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

  if (g_INPUT_WIDTH > g_OUTPUT_WIDTH) begin : gen_down_conversion
    logic gbx_valid;
    logic [g_OUTPUT_WIDTH-1:0] gbx_data_out;
    gearbox #(
      .g_INPUT_WIDTH(g_INPUT_WIDTH),
      .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH)
    ) gearbox_inst (
      .clk_i(rdclk_i),
      .reset_i(rd_reset),
      .snk_data_i(data_out),
      .snk_valid_i(~rdempty),
      .snk_ready_o(rdreq),
      .src_data_o(gbx_data_out),
      .src_valid_o(gbx_valid),
      .src_ready_i(rdreq_i)
    );
    assign rdempty_o = ~gbx_valid;
    if (g_ENABLE_FWFT) begin : gen_output_delay
      assign q_o = gbx_data_out;
    end else begin : gen_output_reg
      always_ff @(posedge rdclk_i) begin : proc_output_delay
        q_o <= gbx_data_out;
      end
    end
  end else begin : gen_down_passthrough
    assign q_o       = data_out;
    assign rdempty_o = rdempty;
    assign rdreq     = rdreq_i;
  end

endmodule
