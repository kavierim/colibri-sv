// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// RAM-based ring buffer. A write while full overwrites the oldest word.

`timescale 1ns/1ps

module ring_buffer #(
  parameter int g_NUM_WORDS  = 4,
  parameter int g_DATA_WIDTH = 8
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic snk_valid_i,
  output logic [g_DATA_WIDTH-1:0] src_data_o,
  output logic src_valid_o,
  input  logic src_ready_i
);

  typedef struct {
    int head;
    int tail;
    int usedw;
  } sig_t;

  logic [g_DATA_WIDTH-1:0] mem [0:g_NUM_WORDS-1];
  // ring_buffer.psl reads rreg.usedw from the bound checker.
  sig_t rreg /* verilator public */;
  sig_t rcmb;

  initial rreg = '{head: 0, tail: 0, usedw: 0};

  always_ff @(posedge clk_i) begin : proc_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_main
    sig_t v_int;
    v_int = rreg;

    if (snk_valid_i) begin
      if (rreg.head != (g_NUM_WORDS - 1))
        v_int.head = rreg.head + 1;
      else
        v_int.head = 0;
    end

    if (snk_valid_i) begin
      if ((src_ready_i == 1'b0) || (rreg.usedw == 0)) begin
        if (rreg.usedw != g_NUM_WORDS)
          v_int.usedw = rreg.usedw + 1;
      end
    end else if ((src_ready_i == 1'b1) && (rreg.usedw != 0)) begin
      v_int.usedw = rreg.usedw - 1;
    end

    if (((rreg.usedw == g_NUM_WORDS) && snk_valid_i) ||
        ((src_ready_i == 1'b1) && (rreg.usedw != 0))) begin
      if (rreg.tail != (g_NUM_WORDS - 1))
        v_int.tail = rreg.tail + 1;
      else
        v_int.tail = 0;
    end

    if (reset_i)
      v_int = '{head: 0, tail: 0, usedw: 0};

    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_mem
    if (snk_valid_i)
      mem[rreg.head] <= snk_data_i;
  end

  assign src_valid_o = (rreg.usedw != 0);
  assign src_data_o  = src_valid_o ? mem[rreg.tail] : '0;

endmodule
