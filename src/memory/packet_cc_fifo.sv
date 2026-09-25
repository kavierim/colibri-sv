// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Dual-clock packet FIFO. Reset and packet-count crossing use synchro_reset
// and synchro (src/common). Payload storage is cc_fifo.

`timescale 1ns/1ps

module packet_cc_fifo #(
  parameter int g_MAX_PACKET_BYTES  = 256,
  parameter int g_NUM_PACKETS       = 4,
  parameter int g_USEDP_BITS        = colibri_utils::log2ceil(g_NUM_PACKETS),
  parameter bit g_ENABLE_SIZE_COUNT = 1'b1,
  parameter int g_PKT_SIZE_BITS     = colibri_utils::log2ceil(g_MAX_PACKET_BYTES) + 1,
  parameter int g_DATA_WIDTH        = 8
) (
  input  logic wrclk_i,
  input  logic reset_i,
  input  logic rdclk_i,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_USEDP_BITS))-1:0] wrusedp_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_USEDP_BITS))-1:0] rdusedp_o,
  output logic wrempty_o,
  output logic wrfull_o,
  output logic rdempty_o,
  output logic rdfull_o,
  output logic snk_ready_o,
  input  logic snk_valid_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i,
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic src_ready_i,
  output logic src_valid_o,
  output logic src_sop_o,
  output logic src_eop_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o,
  output logic [g_DATA_WIDTH-1:0] src_data_o,
  output logic [g_PKT_SIZE_BITS-1:0] src_size_o
);

  localparam int c_PACKET_WORDS = colibri_utils::div_ceil(g_MAX_PACKET_BYTES * 8, g_DATA_WIDTH);
  localparam int c_EMPTY_W      = colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8));
  localparam int c_RECORD_BITS  = 1 + 1 + g_DATA_WIDTH + c_EMPTY_W;
  localparam int c_SIZE_W       = colibri_utils::log2ceil(g_MAX_PACKET_BYTES) + 1;
  localparam int c_PTR_W        = colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_PACKETS));
  localparam int c_USEDP_W      = colibri_utils::downto_width(colibri_utils::log2ceil(g_USEDP_BITS));

  typedef struct packed {
    logic                    sop;
    logic                    eop;
    logic [c_EMPTY_W-1:0]    empty;
    logic [g_DATA_WIDTH-1:0] data;
  } record_t;

  typedef struct {
    int count;
    logic wreq;
    logic rreq;
    logic ready;
    logic valid;
    record_t orecord;
  } sig_t;

  function automatic logic [c_RECORD_BITS-1:0] record_to_slv(input record_t arg);
    return {arg.sop, arg.eop, arg.empty, arg.data};
  endfunction

  function automatic record_t slv_to_record(input logic [c_RECORD_BITS-1:0] arg);
    record_t v_res;
    v_res.sop   = arg[c_RECORD_BITS-1];
    v_res.eop   = arg[c_RECORD_BITS-2];
    v_res.empty = arg[g_DATA_WIDTH +: c_EMPTY_W];
    v_res.data  = arg[g_DATA_WIDTH-1:0];
    return v_res;
  endfunction

  record_t rsnk;
  record_t rsrc;
  logic [c_RECORD_BITS-1:0] snk_rec_slv;
  logic [c_RECORD_BITS-1:0] src_rec_slv;
  logic fifo_empty;
  logic fifo_full;
  logic fifo_wreq;
  int wr_ptr;
  int rd_ptr;
  int rwr_ptr;
  int wrd_ptr;
  logic [c_PTR_W-1:0] wr_ptr_gray;
  logic [c_PTR_W-1:0] rd_ptr_gray;
  logic [c_PTR_W-1:0] rwr_ptr_gray;
  logic [c_PTR_W-1:0] wrd_ptr_gray;
  int int_rusedp;
  int int_wusedp;
  logic src_reset;
  logic [c_SIZE_W-1:0] int_size;
  sig_t rreg;
  sig_t rcmb;

  initial begin
    wr_ptr = 0;
    rd_ptr = 0;
    rreg = '{
      count: 0,
      wreq: 1'b0,
      rreq: 1'b0,
      ready: 1'b0,
      valid: 1'b0,
      orecord: '0
    };
  end

  synchro_reset #(
    .g_IN_POLARITY(1'b1),
    .g_OUT_POLARITY(1'b1),
    .g_DURATION(1)
  ) wr_synchro_reset (
    .clk_i(rdclk_i),
    .reset_i(reset_i),
    .reset_o(src_reset)
  );

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
    .reset_i(src_reset),
    .data_i(wr_ptr_gray),
    .data_o(rwr_ptr_gray)
  );

  synchro #(
    .g_DATA_LENGTH(c_PTR_W),
    .g_NUM_STAGES(2)
  ) rd_ptr_synchro (
    .clk_i(wrclk_i),
    .reset_i(reset_i),
    .data_i(rd_ptr_gray),
    .data_o(wrd_ptr_gray)
  );

  assign int_wusedp = (wr_ptr < wrd_ptr) ? (g_NUM_PACKETS + wr_ptr - wrd_ptr) : (wr_ptr - wrd_ptr);
  assign wrusedp_o  = c_USEDP_W'(int_wusedp);
  assign int_rusedp = (rwr_ptr < rd_ptr) ? (g_NUM_PACKETS + rwr_ptr - rd_ptr) : (rwr_ptr - rd_ptr);
  assign rdusedp_o  = c_USEDP_W'(int_rusedp);
  assign wrfull_o   = (int_wusedp == (g_NUM_PACKETS - 1));
  assign wrempty_o  = (int_wusedp == 0);
  assign rdfull_o   = (int_rusedp == (g_NUM_PACKETS - 1));
  assign rdempty_o  = (int_rusedp == 0);

  assign rsnk.sop    = snk_sop_i;
  assign rsnk.eop    = snk_eop_i;
  assign rsnk.empty  = snk_empty_i;
  assign rsnk.data   = snk_data_i;
  assign snk_rec_slv = record_to_slv(rsnk);
  assign snk_ready_o = (!fifo_full && !wrfull_o);
  assign fifo_wreq   = snk_valid_i & snk_ready_o;

  always_ff @(posedge wrclk_i) begin : proc_cnt_packets
    if (reset_i)
      wr_ptr <= 0;
    else if (fifo_wreq && rsnk.eop) begin
      if (wr_ptr == (g_NUM_PACKETS - 1))
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1;
    end
  end

  // Status and peek ports left open match the VHDL port map.
  // verilator lint_off PINMISSING
  cc_fifo #(
    .g_NUM_WORDS(c_PACKET_WORDS * g_NUM_PACKETS),
    .g_INPUT_WIDTH(c_RECORD_BITS),
    .g_OUTPUT_WIDTH(c_RECORD_BITS),
    .g_ENABLE_FWFT(1'b1)
  ) cc_fifo_inst (
    .wrclk_i(wrclk_i),
    .reset_i(reset_i),
    .rdclk_i(rdclk_i),
    .data_i(snk_rec_slv),
    .wrreq_i(fifo_wreq),
    .rdreq_i(rcmb.rreq),
    .q_o(src_rec_slv),
    .wrfull_o(fifo_full),
    .rdempty_o(fifo_empty)
  );
  // verilator lint_on PINMISSING

  if (g_ENABLE_SIZE_COUNT) begin : gen_size_count_fifo
    logic [c_SIZE_W-1:0] cmb_size;
    logic [c_SIZE_W-1:0] reg_size;

    always_comb begin : proc_size_cnt_cmb
      logic [c_SIZE_W-1:0] v_int;
      v_int = reg_size;
      if (snk_valid_i && snk_ready_o) begin
        if (snk_sop_i)
          v_int = '0;
        v_int = v_int + c_SIZE_W'(g_DATA_WIDTH / 8);
        if (snk_eop_i)
          v_int = v_int - c_SIZE_W'(snk_empty_i);
      end
      cmb_size = v_int;
    end

    always_ff @(posedge wrclk_i) begin : proc_size_reg
      reg_size <= cmb_size;
    end

    // verilator lint_off PINMISSING
    cc_fifo #(
      .g_NUM_WORDS(g_NUM_PACKETS),
      .g_INPUT_WIDTH(c_SIZE_W),
      .g_OUTPUT_WIDTH(c_SIZE_W),
      .g_ENABLE_FWFT(1'b1)
    ) size_fifo_inst (
      .wrclk_i(wrclk_i),
      .reset_i(reset_i),
      .rdclk_i(rdclk_i),
      .data_i(cmb_size),
      .wrreq_i(fifo_wreq & snk_eop_i),
      .rdreq_i(rcmb.rreq & rsrc.sop),
      .q_o(int_size)
    );
    // verilator lint_on PINMISSING
  end else begin : gen_size_tieoff
    assign int_size = '0;
  end

  assign rsrc = slv_to_record(src_rec_slv);

  always_ff @(posedge rdclk_i) begin : proc_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_read_logic
    sig_t v_int;
    v_int      = rreg;
    v_int.rreq = 1'b0;

    if (src_ready_i && rreg.valid)
      v_int.valid = 1'b0;

    if (!v_int.valid && !fifo_empty && !rdempty_o) begin
      v_int.rreq    = 1'b1;
      v_int.valid   = 1'b1;
      v_int.orecord = rsrc;
      if (rsrc.eop) begin
        if (rd_ptr == (g_NUM_PACKETS - 1))
          v_int.count = 0;
        else
          v_int.count = rreg.count + 1;
      end
    end

    if (src_reset) begin
      v_int.count   = 0;
      v_int.wreq    = 1'b0;
      v_int.rreq    = 1'b0;
      v_int.ready   = 1'b0;
      v_int.valid   = 1'b0;
      v_int.orecord = '0;
    end

    rcmb = v_int;
  end

  assign rd_ptr      = rreg.count;
  assign src_sop_o   = rreg.orecord.sop;
  assign src_eop_o   = rreg.orecord.eop;
  assign src_empty_o = rreg.orecord.empty;
  assign src_data_o  = rreg.orecord.data;
  assign src_valid_o = rreg.valid;
  assign src_size_o  = rreg.valid ? g_PKT_SIZE_BITS'(int_size) : '0;

endmodule
