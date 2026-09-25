// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Avalon-ST width converter.
// Converts the data width of an Avalon stream, including packet delimiters
// (start and end of packet) and empty symbols. Symbol width is unchanged.

`timescale 1ns/1ps

module avst_width_converter #(
  parameter int unsigned g_SYM_WIDTH  = 8,
  parameter int unsigned g_INPUT_SYM  = 16,
  parameter int unsigned g_OUTPUT_SYM = 1,
  localparam int c_INPUT_WIDTH  = int'(g_SYM_WIDTH) * int'(g_INPUT_SYM),
  localparam int c_OUTPUT_WIDTH = int'(g_SYM_WIDTH) * int'(g_OUTPUT_SYM),
  localparam int c_SNK_EMPTY_W  = colibri_types::avst_empty_width(c_INPUT_WIDTH, int'(g_SYM_WIDTH)),
  localparam int c_SRC_EMPTY_W  = colibri_types::avst_empty_width(c_OUTPUT_WIDTH, int'(g_SYM_WIDTH))
) (
  input  logic                       clk_i,
  input  logic                       reset_i,
  output logic                       snk_ready_o,
  input  logic                       snk_valid_i,
  input  logic                       snk_sop_i,
  input  logic                       snk_eop_i,
  input  logic [c_SNK_EMPTY_W-1:0]   snk_empty_i,
  input  logic [c_INPUT_WIDTH-1:0]   snk_data_i,
  input  logic                       src_ready_i,
  output logic                       src_valid_o,
  output logic                       src_sop_o,
  output logic                       src_eop_o,
  output logic [c_SRC_EMPTY_W-1:0]   src_empty_o,
  output logic [c_OUTPUT_WIDTH-1:0]  src_data_o
);

  // Two '::' on a class specialization do not elaborate, so import the class.
  import colibri_types::avst;

  localparam int c_BUF_WORDS = colibri_utils::div_ceil(int'(g_OUTPUT_SYM), int'(g_INPUT_SYM)) + 1;
  localparam int c_BUF_SYM   = c_BUF_WORDS * int'(g_INPUT_SYM);
  localparam int c_BUF_BITS  = c_BUF_SYM * int'(g_SYM_WIDTH);

  `COLIBRI_AVST_MASTER_T(avst_t, c_OUTPUT_WIDTH, c_SRC_EMPTY_W);

  typedef struct packed {
    avst_t                   avst_src;
    logic                    snk_ready;
    // VHDL field name `buf` is a Verilog gate primitive.
    logic [c_BUF_BITS-1:0]   data_buf;
    int                      sym_cnt;
    int                      bit_cnt;
    logic [c_BUF_SYM-1:0]    sop_buf;
    logic [c_BUF_SYM-1:0]    eop_buf;
  } reg_t;

  function automatic avst_t avst_from_init();
    avst#(c_OUTPUT_WIDTH, int'(g_SYM_WIDTH))::master_t v_init;
    avst_t v_avst;
    v_init = avst#(c_OUTPUT_WIDTH, int'(g_SYM_WIDTH))::master_init();
    v_avst.data  = v_init.data;
    v_avst.empty = v_init.empty;
    v_avst.sop   = v_init.sop;
    v_avst.eop   = v_init.eop;
    v_avst.valid = v_init.valid;
    return v_avst;
  endfunction

  function automatic reg_t reg_init();
    reg_t v;
    v           = '0;
    v.avst_src  = avst_from_init();
    return v;
  endfunction

  // Mark the first symbol of an input word with SoP.
  function automatic logic [g_INPUT_SYM-1:0] sop_tail(input logic sop);
    logic [int'(g_INPUT_SYM)-1:0] v_out;
    v_out = '0;
    v_out[int'(g_INPUT_SYM)-1] = sop;
    return v_out;
  endfunction

  // Mark one symbol of an input word with EoP.
  function automatic logic [g_INPUT_SYM-1:0] eop_tail(
    input logic eop,
    input logic [c_SNK_EMPTY_W-1:0] empty
  );
    logic [int'(g_INPUT_SYM)-1:0] v_out;
    v_out = '0;
    v_out[int'(empty)] = eop;
    return v_out;
  endfunction

  function automatic logic is_eop(input logic [c_BUF_SYM-1:0] eop_buf, input int ptr);
    logic v_or;
    if (ptr == 0)
      return 1'b0;
    v_or = 1'b0;
    if (ptr < int'(g_OUTPUT_SYM)) begin
      for (int i = 0; i < ptr; i++)
        v_or |= eop_buf[i];
    end else begin
      for (int i = 0; i < int'(g_OUTPUT_SYM); i++)
        v_or |= eop_buf[ptr - int'(g_OUTPUT_SYM) + i];
    end
    return v_or;
  endfunction

  function automatic int get_empty(input logic [c_BUF_SYM-1:0] eop_buf, input int ptr);
    for (int i = 1; i <= int'(g_OUTPUT_SYM); i++) begin
      if (i > ptr)
        return int'(g_OUTPUT_SYM) - i + 1;
      else if (eop_buf[ptr - i])
        return int'(g_OUTPUT_SYM) - i;
    end
    return 0;
  endfunction

  reg_t r = reg_init();
  reg_t rin;

  // Two-process structure.
  always_comb begin : proc_comb
    reg_t v;
    logic [c_BUF_BITS+c_OUTPUT_WIDTH-1:0] v_padded_buf;

    v_padded_buf = '0;
    v_padded_buf[c_BUF_BITS+c_OUTPUT_WIDTH-1:c_OUTPUT_WIDTH] = r.data_buf;
    v = r;

    if (r.snk_ready && snk_valid_i) begin
      v.data_buf = {r.data_buf[c_BUF_BITS-c_INPUT_WIDTH-1:0], snk_data_i};
      v.sym_cnt  = r.sym_cnt + int'(g_INPUT_SYM);
      v.bit_cnt  = r.bit_cnt + c_INPUT_WIDTH;
      v.sop_buf  = {r.sop_buf[c_BUF_SYM-int'(g_INPUT_SYM)-1:0], sop_tail(snk_sop_i)};
      v.eop_buf  = {r.eop_buf[c_BUF_SYM-int'(g_INPUT_SYM)-1:0], eop_tail(snk_eop_i, snk_empty_i)};
    end

    if (src_ready_i && r.avst_src.valid)
      v.avst_src = avst_from_init();

    if (v.avst_src.valid == 1'b0) begin
      if (is_eop(r.eop_buf, r.sym_cnt) == 1'b1) begin
        v.avst_src = '{
          data:  v_padded_buf[r.bit_cnt +: c_OUTPUT_WIDTH],
          empty: c_SRC_EMPTY_W'(get_empty(r.eop_buf, r.sym_cnt)),
          sop:   r.sop_buf[r.sym_cnt-1],
          eop:   1'b1,
          valid: 1'b1
        };
        v.sym_cnt = v.sym_cnt - int'(g_OUTPUT_SYM) + int'(v.avst_src.empty);
        v.sym_cnt = v.sym_cnt - (v.sym_cnt % int'(g_INPUT_SYM));
        v.bit_cnt = v.sym_cnt * int'(g_SYM_WIDTH);
      end else if (r.sym_cnt >= int'(g_OUTPUT_SYM)) begin
        v.avst_src = '{
          data:  r.data_buf[(r.bit_cnt - c_OUTPUT_WIDTH) +: c_OUTPUT_WIDTH],
          empty: '0,
          sop:   r.sop_buf[r.sym_cnt-1],
          eop:   1'b0,
          valid: 1'b1
        };
        v.bit_cnt = v.bit_cnt - c_OUTPUT_WIDTH;
        v.sym_cnt = v.sym_cnt - int'(g_OUTPUT_SYM);
      end
    end

    v.snk_ready = colibri_types::bool_to_sl(
      bit'((c_BUF_SYM - v.sym_cnt) >= int'(g_INPUT_SYM))
    );

    if (reset_i)
      v = reg_init();

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_seq
    r <= rin;
  end

  assign snk_ready_o = r.snk_ready;
  assign src_data_o  = r.avst_src.data;
  assign src_sop_o   = r.avst_src.sop;
  assign src_eop_o   = r.avst_src.eop;
  assign src_empty_o = r.avst_src.empty;
  assign src_valid_o = r.avst_src.valid;

endmodule
