// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Slip buffer for stream synchronization.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module slip_buffer #(
  parameter int unsigned g_DATA_WIDTH = 64
) (
  input  logic                    clk_i,
  input  logic                    reset_i,      // active high
  input  logic                    slip_i,       // slip pulse which triggers shift
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic                    snk_valid_i,
  output logic                    snk_ready_o,
  output logic                    src_valid_o,
  input  logic                    src_ready_i,
  output logic [g_DATA_WIDTH-1:0] src_data_o
);

  localparam int c_BUF_WIDTH = g_DATA_WIDTH * 2;

  // VHDL field name `buf` is a Verilog primitive keyword.
  typedef struct packed {
    logic                    valid;
    logic                    ready;
    logic [c_BUF_WIDTH-1:0]  word_buf;
    logic [g_DATA_WIDTH-1:0] data;
    int unsigned             slip;
  } sig_t;

  sig_t rreg = '0;
  sig_t rcmb;

  always_comb begin : proc_slip_main
    sig_t v_int;
    v_int = rreg;

    if (src_ready_i && rreg.valid)
      v_int.valid = 1'b0;

    // Ready is sampled before the input is accepted.
    v_int.ready = ~v_int.valid;

    if (snk_valid_i && !v_int.valid) begin
      v_int.valid    = 1'b1;
      v_int.word_buf = {v_int.word_buf[g_DATA_WIDTH-1:0], snk_data_i};
    end

    if (slip_i) begin
      if (rreg.slip == g_DATA_WIDTH - 1)
        v_int.slip = 0;
      else
        v_int.slip = v_int.slip + 1;
    end

    for (int i = 0; i < g_DATA_WIDTH; i++) begin
      if (i == int'(v_int.slip))
        v_int.data = v_int.word_buf[g_DATA_WIDTH - 1 + i -: g_DATA_WIDTH];
    end

    if (reset_i) begin
      v_int.valid    = 1'b0;
      v_int.ready    = 1'b0;
      v_int.slip     = 0;
      v_int.word_buf = '0;
      v_int.data     = '0;
    end

    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_slip_reg
    rreg <= rcmb;
  end

  assign src_valid_o = rreg.valid;
  assign snk_ready_o = rcmb.ready;
  assign src_data_o  = rreg.data;

endmodule
