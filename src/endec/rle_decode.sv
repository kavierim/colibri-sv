// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Run-Length Decoder
// Some of the work was inspired by VHDL Whiz
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

// Library entity. Lint alongside verilator/wave0_elab.sv reports multiple tops.
// verilator lint_off MULTITOP
module rle_decode #(
  parameter int unsigned g_WORD_WIDTH  = 16,
  parameter int unsigned g_COUNT_WIDTH = 3
) (
  input  logic                                      clk_i,
  input  logic                                      reset_i,
  output logic                                      snk_ready_o,
  input  logic                                      snk_valid_i,
  input  logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0]     snk_data_i,
  input  logic                                      src_ready_i,
  output logic                                      src_valid_o,
  output logic [g_WORD_WIDTH-1:0]                   src_data_o
);

  localparam int unsigned c_WORD_MAX = (2 ** g_COUNT_WIDTH) - 1;
  localparam int unsigned c_DATA_WIDTH = g_WORD_WIDTH + g_COUNT_WIDTH;
  // VHDL word_cnt is natural range 0 to c_WORD_MAX.
  localparam int c_CNT_W = colibri_utils::log2ceil(int'(c_WORD_MAX + 1));

  typedef struct packed {
    logic [c_CNT_W-1:0] word_cnt;
    // VHDL field name `buf` is the Verilog primitive keyword.
    logic [c_DATA_WIDTH-1:0]  word_buf;
    logic [g_WORD_WIDTH-1:0]  odata;
    logic                     valid;
    logic                     start;
    logic                     ready;
  } sig_t;

  localparam sig_t c_SIG_INIT = '{
    word_cnt: '0,
    word_buf: '0,
    odata:    '0,
    valid:    1'b0,
    start:    1'b0,
    ready:    1'b0
  };

  sig_t                    rreg = c_SIG_INIT;
  sig_t                    rcmb;
  logic [c_DATA_WIDTH-1:0] skid_data;
  logic                    skid_valid;

  // Sideband inputs are tied off. VHDL leaves src_empty_o, src_keep_o,
  // src_sop_o, and src_eop_o open.
  // verilator lint_off PINMISSING
  skid_buffer #(
    .g_DATA_WIDTH (c_DATA_WIDTH)
  ) skid_buffer_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .snk_empty_i ('0),
    .snk_keep_i  ('0),
    .snk_sop_i   (1'b0),
    .snk_eop_i   (1'b0),
    .snk_data_i  (snk_data_i),
    .snk_valid_i (snk_valid_i),
    .snk_ready_o (snk_ready_o),
    .src_data_o  (skid_data),
    .src_valid_o (skid_valid),
    .src_ready_i (rcmb.ready)
  );
  // verilator lint_on PINMISSING

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

  always_comb begin : proc_encode
    sig_t v_int;
    v_int = rreg;

    // acknowledge a read
    if (src_ready_i && rreg.valid) begin
      v_int.valid = 1'b0;
      if (rreg.start) begin
        v_int.word_cnt = rreg.word_cnt - c_CNT_W'(1);
        v_int.start    = 1'b0;
      end
    end

    if (!v_int.valid && (v_int.word_cnt != '0)) begin
      v_int.valid    = 1'b1;
      v_int.odata    = rreg.word_buf[g_WORD_WIDTH-1:0];
      v_int.word_cnt = v_int.word_cnt - c_CNT_W'(1);
    end

    v_int.ready = ~v_int.valid;

    // if input is valid and no word is buffered
    if (skid_valid && v_int.ready) begin
      v_int.word_buf = skid_data;
      v_int.start    = 1'b1;
      v_int.word_cnt = c_CNT_W'(skid_data[c_DATA_WIDTH-1:g_WORD_WIDTH]);
      // forward the current word
      v_int.valid    = 1'b1;
      v_int.odata    = skid_data[g_WORD_WIDTH-1:0];
    end

    if (reset_i)
      v_int = c_SIG_INIT;

    rcmb = v_int;
  end

  assign src_data_o  = rreg.odata;
  assign src_valid_o = rreg.valid;

endmodule
