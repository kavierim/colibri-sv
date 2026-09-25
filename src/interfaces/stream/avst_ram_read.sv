// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple Avalon Stream to RAM reader.
// Sequential reads through a RAM interface, presented as a packeted Avalon-ST
// output. length_i is a byte count. A length of 0 reads until stop_i.
// start_i is accepted only while busy_o is low. stop_i ends the transfer.

`timescale 1ns/1ps

module avst_ram_read #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  // VHDL leaves these without defaults. Verilator elaborates this module on
  // its own, so defaults are required. Instantiations still pass them.
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 16,
  localparam int c_ADDR_RAW    = colibri_utils::log2ceil(int'(g_RAM_DEPTH)),
  localparam int c_ADDR_W      = colibri_utils::downto_width(c_ADDR_RAW),
  localparam int c_WORD_CNT_W  = c_ADDR_RAW + 1,
  localparam int c_LEN_W       = colibri_utils::log2ceil(
    int'(g_RAM_DEPTH) * int'(g_WORD_BYTES) + 1),
  localparam int c_DATA_W      = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W     = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_CMP_W       = colibri_utils::maximum(c_WORD_CNT_W, c_LEN_W),
  localparam int c_EMPTY_CALC_W = (2 * c_LEN_W) + c_WORD_CNT_W + 1
) (
  input  logic                     clk_i,
  input  logic                     reset_i,
  output logic [c_DATA_W-1:0]      src_data_o,
  output logic [c_EMPTY_W-1:0]     src_empty_o,
  output logic                     src_sop_o,
  output logic                     src_eop_o,
  output logic                     src_valid_o,
  input  logic                     src_ready_i,
  input  logic [c_ADDR_W-1:0]      start_addr_i,
  input  logic [c_LEN_W-1:0]       length_i,
  input  logic                     start_i,
  input  logic                     stop_i,
  output logic                     busy_o,
  output logic                     rd_en_o,
  output logic [c_ADDR_W-1:0]      rd_addr_o,
  input  logic [c_DATA_W-1:0]      rd_data_i
);

  // Two '::' on a class specialization do not elaborate, so import the class.
  import colibri_types::avst;

  `COLIBRI_AVST_MASTER_T(avst_t, c_DATA_W, c_EMPTY_W);

  typedef struct packed {
    logic                  en;
    logic [c_ADDR_W-1:0]   addr;
  } ram_rd_t;

  typedef struct {
    logic                        busy;
    logic                        continuous;
    logic [c_LEN_W-1:0]          length;
    logic [c_WORD_CNT_W-1:0]     word_cnt;
    logic [c_ADDR_W-1:0]         addr;
    ram_rd_t                     ram_rd;
    avst_t                       avst_pipe [0:2];
  } reg_t;

  localparam ram_rd_t c_RAM_RD_INIT = '{en: 1'b0, addr: '0};

  function automatic avst_t avst_from_init();
    avst#(c_DATA_W, int'(g_BYTE_WIDTH))::master_t v_init;
    avst_t v_avst;
    v_init = avst#(c_DATA_W, int'(g_BYTE_WIDTH))::master_init();
    v_avst.data  = v_init.data;
    v_avst.empty = v_init.empty;
    v_avst.sop   = v_init.sop;
    v_avst.eop   = v_init.eop;
    v_avst.valid = v_init.valid;
    return v_avst;
  endfunction

  function automatic reg_t reg_init();
    reg_t v;
    v.busy       = 1'b0;
    v.continuous = 1'b0;
    v.length     = '0;
    v.word_cnt   = '0;
    v.addr       = '0;
    v.ram_rd     = c_RAM_RD_INIT;
    for (int i = 0; i < 3; i++)
      v.avst_pipe[i] = avst_from_init();
    return v;
  endfunction

  reg_t r /* verilator public */ = reg_init();
  reg_t rin;

  // Two-process structure.
  always_comb begin : proc_comb
    reg_t v;
    logic [c_EMPTY_CALC_W-1:0] v_empty_full;
    v = r;
    v_empty_full = '0;

    if ((start_i == 1'b1) && (r.busy == 1'b0) && (stop_i == 1'b0)) begin
      v.busy       = 1'b1;
      v.continuous = 1'b0;
      v.addr       = start_addr_i;
      v.length     = length_i;
      v.word_cnt   = '0;
    end

    if ((src_ready_i == 1'b1) && (src_valid_o == 1'b1))
      v.avst_pipe[2] = avst_from_init();

    if ((r.avst_pipe[0].valid == 1'b1) && (r.avst_pipe[1].valid == 1'b0)) begin
      v.avst_pipe[1].data  = rd_data_i;
      v.avst_pipe[1].valid = 1'b1;
      v.avst_pipe[1].sop   = r.avst_pipe[0].sop;
      v.avst_pipe[1].eop   = r.avst_pipe[0].eop;
      v.avst_pipe[1].empty = r.avst_pipe[0].empty;
      v.avst_pipe[0]       = avst_from_init();
    end

    if ((v.avst_pipe[1].valid == 1'b1) && (v.avst_pipe[2].valid == 1'b0)) begin
      v.avst_pipe[2].data  = v.avst_pipe[1].data;
      v.avst_pipe[2].empty = v.avst_pipe[1].empty;
      v.avst_pipe[2].eop   = v.avst_pipe[1].eop;
      v.avst_pipe[2].sop   = v.avst_pipe[1].sop;
      v.avst_pipe[2].valid = 1'b1;
      v.avst_pipe[1]       = avst_from_init();
    end

    v.ram_rd = c_RAM_RD_INIT;
    if ((v.busy == 1'b1) && (v.avst_pipe[1].valid == 1'b0)) begin
      v.ram_rd   = '{en: 1'b1, addr: v.addr};
      v.addr     = v.addr + c_ADDR_W'(1);
      v.word_cnt = v.word_cnt + c_WORD_CNT_W'(1);
    end

    if (r.ram_rd.en) begin
      v.avst_pipe[0].valid = 1'b1;
      if (r.word_cnt == c_WORD_CNT_W'(1)) begin
        v.avst_pipe[0].sop = ~r.continuous;
        v.continuous       = colibri_types::bool_to_sl(bit'(r.length == '0));
      end
      if ((r.length != '0) &&
          (c_CMP_W'(r.word_cnt) == c_CMP_W'(
            colibri_utils::uval#(c_LEN_W)::div_ceil(r.length, int'(g_WORD_BYTES))))) begin
        v.avst_pipe[0].eop = 1'b1;
        v_empty_full = c_EMPTY_CALC_W'(g_WORD_BYTES) * c_EMPTY_CALC_W'(r.word_cnt)
                     - c_EMPTY_CALC_W'(r.length);
        v.avst_pipe[0].empty = v_empty_full[c_EMPTY_W-1:0];
      end
    end

    if ((v.length != '0) &&
        (c_CMP_W'(v.word_cnt) == c_CMP_W'(
          colibri_utils::uval#(c_LEN_W)::div_ceil(v.length, int'(g_WORD_BYTES)))))
      v.busy = 1'b0;

    if (stop_i) begin
      v.busy           = 1'b0;
      v.ram_rd.en      = 1'b0;
      v.avst_pipe[0]   = avst_from_init();
      v.avst_pipe[1]   = avst_from_init();
      v.avst_pipe[2].eop = v.avst_pipe[2].valid;
      if (v.avst_pipe[2].sop)
        v.avst_pipe[2] = avst_from_init();
    end

    if (reset_i)
      v = reg_init();

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_seq
    r <= rin;
  end

  assign busy_o      = r.busy;
  assign rd_en_o     = r.ram_rd.en;
  assign rd_addr_o   = r.ram_rd.addr;
  assign src_data_o  = r.avst_pipe[2].data;
  assign src_empty_o = r.avst_pipe[2].empty;
  assign src_sop_o   = r.avst_pipe[2].sop;
  assign src_eop_o   = r.avst_pipe[2].eop;
  assign src_valid_o = r.avst_pipe[2].valid;

endmodule
