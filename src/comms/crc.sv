// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Cyclic redundancy check for a packet stream. The CRC is presented with
// the end-of-packet word.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module crc #(
  parameter int unsigned g_DATA_WIDTH = 64,
  parameter g_CRC_POLY = colibri_poly::c_CRC_8,
  parameter g_INIT_VAL = {$bits(g_CRC_POLY){1'b0}},
  parameter g_XOR_OUT = {$bits(g_CRC_POLY){1'b0}},
  parameter bit g_INVERT_IN = 1'b0,
  parameter bit g_INVERT_OUT = 1'b0
) (
  input  logic                    clk_i,
  input  logic                    reset_i,
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic                    snk_sop_i,
  input  logic                    snk_eop_i,
  input  logic [colibri_types::avst_empty_width(g_DATA_WIDTH, 8)-1:0] snk_empty_i,
  input  logic                    snk_valid_i,
  output logic                    snk_ready_o,
  output logic [g_DATA_WIDTH-1:0] src_data_o,
  output logic                    src_sop_o,
  output logic                    src_eop_o,
  output logic [colibri_types::avst_empty_width(g_DATA_WIDTH, 8)-1:0] src_empty_o,
  output logic                    src_valid_o,
  input  logic                    src_ready_i,
  output logic [$bits(g_CRC_POLY)-1:0] src_crc_o
);

  localparam int c_DATA_BYTES = g_DATA_WIDTH / 8;
  localparam int c_CRC_WIDTH = $bits(g_CRC_POLY);
  localparam int c_BUF_WIDTH = g_DATA_WIDTH + c_CRC_WIDTH;
  localparam int c_CRC_OUT_WIDTH = c_DATA_BYTES * c_CRC_WIDTH;
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(g_DATA_WIDTH, 8);
  localparam int c_KEEP_W = (c_DATA_BYTES > 0) ? c_DATA_BYTES : 1;

  if (($bits(g_INIT_VAL) != c_CRC_WIDTH) || ($bits(g_XOR_OUT) != c_CRC_WIDTH)) begin : gen_poly_len
    $error("ERROR: CRC init and xor-out width must match g_CRC_POLY");
  end

  `COLIBRI_AVST_MASTER_T(avst_m_t, g_DATA_WIDTH, c_EMPTY_W);

  typedef logic [c_BUF_WIDTH-1:0] eq_word_t;
  typedef eq_word_t eqset_t [0:((c_CRC_OUT_WIDTH > 0) ? c_CRC_OUT_WIDTH : 1)-1];

  function automatic avst_m_t avst_clear();
    import colibri_types::avst;
    avst#(g_DATA_WIDTH)::master_t v_init;
    avst_m_t v_out;
    v_init = avst#(g_DATA_WIDTH)::master_init();
    v_out.data  = v_init.data;
    v_out.empty = v_init.empty;
    v_out.sop   = v_init.sop;
    v_out.eop   = v_init.eop;
    v_out.valid = v_init.valid;
    return v_out;
  endfunction

  // Local reverses. bits#(W)::invert_bit_order and xorvec pull in
  // swap_endianness, and Verilator 5.020 does not compile that method.
  function automatic logic [7:0] invert_byte(input logic [7:0] word);
    logic [7:0] v_res;
    for (int i = 0; i < 8; i++)
      v_res[i] = word[7 - i];
    return v_res;
  endfunction

  function automatic logic [c_CRC_WIDTH-1:0] invert_crc(input logic [c_CRC_WIDTH-1:0] word);
    logic [c_CRC_WIDTH-1:0] v_res;
    for (int i = 0; i < c_CRC_WIDTH; i++)
      v_res[i] = word[c_CRC_WIDTH - 1 - i];
    return v_res;
  endfunction

  function automatic logic [g_DATA_WIDTH-1:0] invert_bit_in_bytes(
    input logic [g_DATA_WIDTH-1:0] vec
  );
    logic [g_DATA_WIDTH-1:0] v_res;
    logic [7:0]              v_byte;
    v_res = '0;
    for (int i = 0; i < g_DATA_WIDTH / 8; i++) begin
      v_byte = vec[8*(i+1)-1 -: 8];
      v_res[8*(i+1)-1 -: 8] = invert_byte(v_byte);
    end
    return v_res;
  endfunction

  function automatic eqset_t gen_crc_lineq();
    logic                    v_xor;
    logic [c_BUF_WIDTH-1:0]  v_vec;
    eqset_t                  v_eqs;
    v_eqs = '{default: '0};
    for (int b = 0; b < c_BUF_WIDTH; b++) begin
      for (int byte_i = 1; byte_i <= c_DATA_BYTES; byte_i++) begin
        v_vec    = '0;
        v_vec[b] = 1'b1;
        for (int s = 0; s < (8 * byte_i); s++) begin
          v_xor = v_vec[c_BUF_WIDTH-1] ^ v_vec[g_DATA_WIDTH-1];
          // Independent left shifts. Width 1 becomes 0, matching a VHDL null slice.
          v_vec[c_BUF_WIDTH-1:g_DATA_WIDTH] = v_vec[c_BUF_WIDTH-1:g_DATA_WIDTH] << 1;
          v_vec[g_DATA_WIDTH-1:0]           = v_vec[g_DATA_WIDTH-1:0] << 1;
          if (v_xor)
            v_vec[c_BUF_WIDTH-1:g_DATA_WIDTH] = v_vec[c_BUF_WIDTH-1:g_DATA_WIDTH] ^ g_CRC_POLY;
        end
        for (int lineq = 0; lineq < c_CRC_WIDTH; lineq++)
          v_eqs[(c_DATA_BYTES - byte_i) * c_CRC_WIDTH + lineq][b] = v_vec[g_DATA_WIDTH + lineq];
      end
    end
    return v_eqs;
  endfunction

  typedef struct packed {
    avst_m_t                         avst;
    logic [c_CRC_OUT_WIDTH-1:0]      crcset;
    logic [c_CRC_WIDTH-1:0]          crc;
    logic                            ready;
  } sig_t;

  `COLIBRI_SLV_ARRAY(eqset, 0, ((c_CRC_OUT_WIDTH > 0) ? c_CRC_OUT_WIDTH : 1) - 1, c_BUF_WIDTH);

  avst_m_t snk;
  avst_m_t skid;
  sig_t    rreg;
  sig_t    rcmb;
  logic [c_KEEP_W-1:0] skid_keep_unused;

  initial begin
    eqset         = gen_crc_lineq();
    rreg.avst     = avst_clear();
    rreg.crcset   = '0;
    rreg.crc      = '0;
    rreg.ready    = 1'b0;
  end

  assign snk.valid = snk_valid_i;
  assign snk.sop   = snk_sop_i;
  assign snk.eop   = snk_eop_i;
  assign snk.data  = g_INVERT_IN ? invert_bit_in_bytes(snk_data_i) : snk_data_i;
  assign snk.empty = snk_empty_i;

  skid_buffer #(
    .g_DATA_WIDTH(g_DATA_WIDTH)
  ) skid_buffer_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .snk_data_i(snk.data),
    .snk_empty_i(snk.empty),
    .snk_keep_i('0),
    .snk_sop_i(snk.sop),
    .snk_eop_i(snk.eop),
    .snk_valid_i(snk.valid),
    .snk_ready_o(snk_ready_o),
    .src_data_o(skid.data),
    .src_empty_o(skid.empty),
    .src_keep_o(skid_keep_unused),
    .src_sop_o(skid.sop),
    .src_eop_o(skid.eop),
    .src_valid_o(skid.valid),
    .src_ready_i(rcmb.ready)
  );

  assign src_valid_o = rreg.avst.valid;
  assign src_sop_o   = rreg.avst.sop;
  assign src_eop_o   = rreg.avst.eop;
  // VHDL reflects the output payload with g_INVERT_IN, not g_INVERT_OUT.
  assign src_data_o  = g_INVERT_IN ? invert_bit_in_bytes(rreg.avst.data) : rreg.avst.data;
  assign src_empty_o = rreg.avst.empty;
  assign src_crc_o   = rreg.crc;

  always_comb begin : proc_fsm
    sig_t v_int;
    v_int = rreg;

    if (rreg.avst.valid && src_ready_i) begin
      v_int.avst = avst_clear();
      v_int.crc  = '0;
      if (rreg.avst.eop)
        v_int.crcset[c_CRC_WIDTH-1:0] = g_INIT_VAL;
    end

    v_int.ready = ~v_int.avst.valid;

    if (v_int.ready && skid.valid) begin
      v_int.avst = skid;
      for (int i = 0; i < c_CRC_OUT_WIDTH; i++) begin
        v_int.crcset[i] = ^({rreg.crcset[c_CRC_WIDTH-1:0], skid.data} & eqset[i]);
      end
      if (skid.eop) begin
        v_int.crc = v_int.crcset[(c_CRC_WIDTH * (int'(skid.empty) + 1) - 1) -: c_CRC_WIDTH];
        if (g_INVERT_OUT)
          v_int.crc = invert_crc(v_int.crc);
        v_int.crc = v_int.crc ^ g_XOR_OUT;
      end
    end

    if (reset_i)
      v_int.avst = avst_clear();

    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_fsm_reg
    rreg <= rcmb;
  end

endmodule
