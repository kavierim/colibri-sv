// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Joins consecutive Avalon-ST packets into one. Empty symbols at an input
// end of packet are removed so the next packet follows directly.

`timescale 1ns/1ps

// Library lint elaborates every module; wave0_elab is the other top.
// verilator lint_off MULTITOP
module packet_join #(
  parameter int unsigned g_SYM_WIDTH = 8,
  parameter int unsigned g_DATA_SYM  = 4,
  localparam int c_SYM_W    = int'(g_SYM_WIDTH),
  localparam int c_DATA_W   = int'(g_DATA_SYM) * c_SYM_W,
  localparam int c_EMPTY_W  = colibri_types::avst_empty_width(c_DATA_W, c_SYM_W)
) (
  input  logic                   clk_i,
  input  logic                   reset_i,
  input  logic                   last_i,
  input  logic [c_DATA_W-1:0]    snk_data_i,
  input  logic [c_EMPTY_W-1:0]   snk_empty_i,
  input  logic                   snk_sop_i,
  input  logic                   snk_eop_i,
  input  logic                   snk_valid_i,
  output logic                   snk_ready_o,
  output logic [c_DATA_W-1:0]    src_data_o,
  output logic [c_EMPTY_W-1:0]   src_empty_o,
  output logic                   src_sop_o,
  output logic                   src_eop_o,
  output logic                   src_valid_o,
  input  logic                   src_ready_i
);

  localparam int c_BUF_WORDS = 3;
  localparam int c_BUF_BITS  = c_BUF_WORDS * c_DATA_W;

  typedef colibri_types::avst#(c_DATA_W, c_SYM_W) avst_cls;
  `COLIBRI_AVST_MASTER_T(avst_t, c_DATA_W, c_EMPTY_W);

  typedef struct {
    colibri_types::avst_slave_t       avst_snk;
    avst_t                            avst_src;
    logic [c_BUF_BITS-1:0]            buf_data;
    int                               buf_addr;
    logic [c_BUF_WORDS-1:0]           buf_sop;
    logic [c_BUF_WORDS-1:0]           buf_eop;
    logic [c_EMPTY_W-1:0]             buf_empty [0:c_BUF_WORDS-1];
    logic                             first_pkt;
    logic                             last_pkt;
  } reg_t;

  function automatic avst_t avst_init();
    return avst_t'(avst_cls::master_init());
  endfunction

  function automatic logic [c_DATA_W-1:0] empty_mask(input logic [c_EMPTY_W-1:0] empty);
    logic [c_DATA_W-1:0] v_out;
    v_out = '0;
    for (int i = 0; i < g_DATA_SYM; i++) begin
      for (int j = 0; j < g_SYM_WIDTH; j++)
        v_out[i * c_SYM_W + j] = colibri_types::bool_to_sl(bit'(i >= int'(empty)));
    end
    return v_out;
  endfunction

  function automatic reg_t reg_init();
    reg_t v;
    v.avst_snk  = colibri_types::c_AVST_SLAVE_INIT;
    v.avst_src  = avst_init();
    v.buf_data  = '0;
    v.buf_addr  = 0;
    v.buf_sop   = '0;
    v.buf_eop   = '0;
    for (int i = 0; i < c_BUF_WORDS; i++)
      v.buf_empty[i] = '0;
    v.first_pkt = 1'b1;
    v.last_pkt  = 1'b0;
    return v;
  endfunction

  reg_t r;
  reg_t rin;

  initial r = reg_init();

  always_comb begin : proc_comb
    reg_t v;
    logic [c_BUF_BITS-1:0] v_buf;
    int empty_syms;

    v          = r;
    v_buf      = '0;
    empty_syms = 0;

    if (last_i)
      v.last_pkt = 1'b1;

    // Output handshake: drop the oldest word and shift the buffer toward the MSB.
    if (r.avst_src.valid && src_ready_i) begin
      v.avst_src = avst_init();
      // Concatenation, not <<. Verilator 5.020 miscompiles a wide
      // struct-field shift as VL_SHIFTL_WII.
      v.buf_data = {r.buf_data[c_BUF_BITS-c_DATA_W-1:0], {c_DATA_W{1'b0}}};
      v.buf_addr = r.buf_addr - c_DATA_W;
      v.buf_sop  = r.buf_sop >> 1;
      v.buf_eop  = r.buf_eop >> 1;
      for (int i = 0; i < c_BUF_WORDS - 1; i++)
        v.buf_empty[i] = r.buf_empty[i + 1];
      v.buf_empty[c_BUF_WORDS-1] = '0;
    end

    // Input handshake: insert the masked word at the current fill position.
    if (snk_valid_i && r.avst_snk.ready) begin
      v_buf[c_BUF_BITS-1 -: c_DATA_W] = snk_data_i & empty_mask(snk_empty_i);
      v_buf = v_buf >> v.buf_addr;
      v.buf_data = v.buf_data | v_buf;

      if (snk_sop_i) begin
        if (r.first_pkt) begin
          for (int wi = 0; wi < c_BUF_WORDS; wi++) begin
            if (wi == (v.buf_addr / c_DATA_W))
              v.buf_sop[wi] = 1'b1;
          end
          v.first_pkt = 1'b0;
        end
      end

      if (snk_eop_i) begin
        v.buf_addr = v.buf_addr + (c_DATA_W - c_SYM_W * int'(snk_empty_i));
        if (v.last_pkt) begin
          for (int wi = 0; wi < c_BUF_WORDS; wi++) begin
            if (wi == ((v.buf_addr - 1) / c_DATA_W)) begin
              v.buf_eop[wi] = 1'b1;
              // A zero remainder means the word is full. Empty is then 0.
              // Width-1 empty can hold g_DATA_SYM, so the value must be
              // rewritten rather than left to truncate.
              empty_syms = int'(g_DATA_SYM) - (v.buf_addr % c_DATA_W) / c_SYM_W;
              if (empty_syms == int'(g_DATA_SYM))
                empty_syms = 0;
              v.buf_empty[wi] = c_EMPTY_W'(empty_syms);
            end
          end
          v.buf_addr  = colibri_utils::div_ceil(v.buf_addr, c_DATA_W) * c_DATA_W;
          v.last_pkt  = 1'b0;
          v.first_pkt = 1'b1;
        end
      end else begin
        v.buf_addr = v.buf_addr + c_DATA_W;
      end
    end

    v.avst_snk.ready = colibri_types::bool_to_sl(bit'((c_BUF_BITS - v.buf_addr) >= c_DATA_W));
    v.avst_src.valid = colibri_types::bool_to_sl(bit'(v.buf_addr >= c_DATA_W));
    v.avst_src.data  = v.buf_data[c_BUF_BITS-1 -: c_DATA_W];
    v.avst_src.sop   = v.buf_sop[0];
    v.avst_src.eop   = v.buf_eop[0];
    v.avst_src.empty = v.buf_empty[0];

    if (reset_i)
      v = reg_init();

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_reg
    r <= rin;
  end

  assign snk_ready_o = r.avst_snk.ready;
  assign src_data_o  = r.avst_src.data;
  assign src_empty_o = r.avst_src.empty;
  assign src_sop_o   = r.avst_src.sop;
  assign src_eop_o   = r.avst_src.eop;
  assign src_valid_o = r.avst_src.valid;

endmodule
// verilator lint_on MULTITOP
