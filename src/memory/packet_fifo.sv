// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Single-clock packet FIFO on top of fifo.

`timescale 1ns/1ps

module packet_fifo #(
  parameter int g_MAX_PACKET_BYTES  = 256,
  parameter int g_NUM_PACKETS       = 4,
  parameter int g_USEDP_BITS        = colibri_utils::log2ceil(g_NUM_PACKETS) + 1,
  parameter bit g_ENABLE_SIZE_COUNT = 1'b1,
  parameter int g_PKT_SIZE_BITS     = colibri_utils::log2ceil(g_MAX_PACKET_BYTES) + 1,
  parameter int g_DATA_WIDTH        = 8
) (
  input  logic clk_i,
  input  logic reset_i,
  output logic full_o,
  output logic empty_o,
  output logic [g_USEDP_BITS-1:0] usedp_o,
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
  localparam int c_EMPTY_W      = colibri_types::avst_empty_width(g_DATA_WIDTH, 8);
  localparam int c_RECORD_BITS  = 1 + 1 + g_DATA_WIDTH + c_EMPTY_W;
  localparam int c_SIZE_W       = colibri_utils::log2ceil(g_MAX_PACKET_BYTES) + 1;

  `COLIBRI_AVST_MASTER_T(avst_m_t, g_DATA_WIDTH, c_EMPTY_W);

  typedef struct {
    int pcount;
    logic wreq;
    logic [c_SIZE_W-1:0] size;
    logic rreq;
    logic ready;
    logic valid;
    avst_m_t orecord;
  } sig_t;

  function automatic logic [c_RECORD_BITS-1:0] record_to_slv(input avst_m_t arg);
    return {arg.sop, arg.eop, arg.empty, arg.data};
  endfunction

  function automatic avst_m_t slv_to_record(input logic [c_RECORD_BITS-1:0] arg);
    avst_m_t v_res;
    v_res.sop   = arg[c_RECORD_BITS-1];
    v_res.eop   = arg[c_RECORD_BITS-2];
    v_res.empty = arg[g_DATA_WIDTH +: c_EMPTY_W];
    v_res.data  = arg[g_DATA_WIDTH-1:0];
    v_res.valid = 1'b0;
    return v_res;
  endfunction

  avst_m_t rsnk;
  avst_m_t rsrc;
  logic [c_RECORD_BITS-1:0] snk_rec_slv;
  logic [c_RECORD_BITS-1:0] src_rec_slv;
  logic empty;
  logic full;
  logic [c_SIZE_W-1:0] int_size;
  sig_t rreg;
  sig_t rcmb;

  initial rreg = '{
    pcount: 0,
    wreq: 1'b0,
    size: '0,
    rreq: 1'b0,
    ready: 1'b0,
    valid: 1'b0,
    orecord: `COLIBRI_AVST_MASTER_INIT
  };

  assign rsnk.sop   = snk_sop_i;
  assign rsnk.eop   = snk_eop_i;
  assign rsnk.empty = snk_empty_i;
  assign rsnk.data  = snk_data_i;
  assign rsnk.valid = 1'b0;
  assign snk_rec_slv = record_to_slv(rsnk);
  assign rsrc = slv_to_record(src_rec_slv);

  // usedw_o is open in the VHDL.
  // verilator lint_off PINMISSING
  fifo #(
    .g_NUM_WORDS(c_PACKET_WORDS * g_NUM_PACKETS),
    .g_INPUT_WIDTH(c_RECORD_BITS),
    .g_OUTPUT_WIDTH(c_RECORD_BITS),
    .g_ENABLE_FWFT(1'b1)
  ) packet_fifo_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .data_i(snk_rec_slv),
    .wrreq_i(rcmb.wreq),
    .rdreq_i(rcmb.rreq),
    .q_o(src_rec_slv),
    .empty_o(empty),
    .full_o(full)
  );
  // verilator lint_on PINMISSING

  if (g_ENABLE_SIZE_COUNT) begin : gen_size_count_fifo
    // usedw_o, empty_o and full_o are open in the VHDL.
    // verilator lint_off PINMISSING
    fifo #(
      .g_NUM_WORDS(g_NUM_PACKETS),
      .g_INPUT_WIDTH(c_SIZE_W),
      .g_OUTPUT_WIDTH(c_SIZE_W),
      .g_ENABLE_FWFT(1'b0)
    ) size_fifo_inst (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .data_i(rcmb.size),
      .wrreq_i(rcmb.wreq & snk_eop_i),
      .rdreq_i(rcmb.rreq & rsrc.sop),
      .q_o(int_size)
    );
    // verilator lint_on PINMISSING
  end else begin : gen_size_tieoff
    assign int_size = '0;
  end

  always_ff @(posedge clk_i) begin : proc_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_packet_fifo_logic
    sig_t v_int;
    v_int       = rreg;
    v_int.wreq  = 1'b0;
    v_int.ready = 1'b0;
    v_int.rreq  = 1'b0;

    if (!full && (rreg.pcount != g_NUM_PACKETS))
      v_int.ready = 1'b1;

    if (snk_valid_i && v_int.ready) begin
      v_int.wreq = 1'b1;
      if (rsnk.sop)
        v_int.size = '0;
      v_int.size = v_int.size + c_SIZE_W'(g_DATA_WIDTH / 8);
      if (rsnk.eop) begin
        v_int.pcount = rreg.pcount + 1;
        v_int.size   = v_int.size - c_SIZE_W'(rsnk.empty);
      end
    end

    if (src_ready_i && rreg.valid)
      v_int.valid = 1'b0;

    if (!v_int.valid && !empty && (rreg.pcount != 0)) begin
      v_int.rreq    = 1'b1;
      v_int.valid   = 1'b1;
      v_int.orecord = rsrc;
      if (rsrc.eop)
        v_int.pcount = v_int.pcount - 1;
    end

    if (reset_i) begin
      v_int.pcount  = 0;
      v_int.wreq    = 1'b0;
      v_int.size    = '0;
      v_int.rreq    = 1'b0;
      v_int.ready   = 1'b0;
      v_int.valid   = 1'b0;
      v_int.orecord = `COLIBRI_AVST_MASTER_INIT;
    end

    rcmb = v_int;
  end

  assign full_o      = ~rcmb.ready;
  assign empty_o     = (rreg.pcount == 0);
  assign usedp_o     = g_USEDP_BITS'(rreg.pcount);
  assign snk_ready_o = rcmb.ready;
  assign src_sop_o   = rreg.orecord.sop;
  assign src_eop_o   = rreg.orecord.eop;
  assign src_empty_o = rreg.orecord.empty;
  assign src_data_o  = rreg.orecord.data;
  assign src_size_o  = rreg.valid ? g_PKT_SIZE_BITS'(int_size) : '0;
  assign src_valid_o = rreg.valid;

endmodule
