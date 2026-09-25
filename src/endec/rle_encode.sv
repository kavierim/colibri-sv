// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Run-Length Encoder
// Some of the work was inspired by VHDL Whiz
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

// Library entity. Lint alongside verilator/wave0_elab.sv reports multiple tops.
// verilator lint_off MULTITOP
module rle_encode #(
  parameter int unsigned g_WORD_WIDTH  = 16,
  parameter int unsigned g_COUNT_WIDTH = 3
) (
  input  logic                                  clk_i,
  input  logic                                  reset_i,
  // flush signal to output words
  input  logic                                  flush_i,
  output logic                                  snk_ready_o,
  input  logic                                  snk_valid_i,
  input  logic [g_WORD_WIDTH-1:0]               snk_data_i,
  input  logic                                  src_ready_i,
  output logic                                  src_valid_o,
  output logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0] src_data_o
);

  localparam int unsigned c_WORD_MAX = (2 ** g_COUNT_WIDTH) - 1;

  typedef struct packed {
    logic [g_COUNT_WIDTH-1:0]                 word_cnt;
    // VHDL field name `buf` is the Verilog primitive keyword.
    logic [g_WORD_WIDTH-1:0]                  word_buf;
    logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0]    odata;
    logic                                     valid;
    logic                                     ready;
    logic                                     flush; // flush seen flag
  } sig_t;

  localparam sig_t c_SIG_INIT = '{
    word_cnt: '0,
    word_buf: '0,
    odata:    '0,
    valid:    1'b0,
    ready:    1'b0,
    flush:    1'b0
  };

  // Bound SVA reads rreg.ready, the same internal the VHDL PSL uses.
  sig_t                        rreg /* verilator public */ = c_SIG_INIT;
  sig_t                        rcmb;
  logic [g_WORD_WIDTH-1:0]     skid_data;
  logic                        skid_valid;

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

  // Sideband inputs are tied off. VHDL leaves src_empty_o, src_keep_o,
  // src_sop_o, and src_eop_o open.
  // verilator lint_off PINMISSING
  skid_buffer #(
    .g_DATA_WIDTH (g_WORD_WIDTH)
  ) skid_buffer_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i | flush_i),
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

  always_comb begin : proc_encode
    sig_t v_int;
    v_int = rreg;

    // acknowledge a read
    if (src_ready_i && rreg.valid) begin
      v_int.valid = 1'b0;
      v_int.odata = '0;
    end

    if (flush_i && (rreg.word_cnt != '0))
      v_int.flush = 1'b1; // set flag

    v_int.ready = ~v_int.valid & ~v_int.flush;

    if (v_int.flush && !v_int.valid) begin
      v_int.flush    = 1'b0; // reset flag
      v_int.valid    = 1'b1;
      v_int.odata    = {rreg.word_cnt, rreg.word_buf};
      v_int.word_cnt = '0;
    end

    // if input is valid and no word is buffered
    if (skid_valid && v_int.ready) begin
      v_int.word_buf = skid_data;
      // if the counter was maxed
      if (rreg.word_cnt == g_COUNT_WIDTH'(c_WORD_MAX)) begin
        v_int.valid    = 1'b1;
        v_int.odata    = {rreg.word_cnt, rreg.word_buf};
        v_int.word_cnt = g_COUNT_WIDTH'(1);
      end else begin
        v_int.word_cnt = rreg.word_cnt + g_COUNT_WIDTH'(1);
      end
      // if it's a new buf
      if ((rreg.word_cnt != '0) && (rreg.word_buf != skid_data)) begin
        v_int.valid    = 1'b1;
        v_int.odata    = {rreg.word_cnt, rreg.word_buf};
        v_int.word_cnt = g_COUNT_WIDTH'(1);
      end
    end

    if (reset_i)
      v_int = c_SIG_INIT;

    rcmb = v_int;
  end

  assign src_data_o  = rreg.odata;
  assign src_valid_o = rreg.valid;

endmodule
