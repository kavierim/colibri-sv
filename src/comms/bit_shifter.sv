// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Bit-shift a continuous stream.
// g_MSB_RIGHT 1 joins the new word on the MSB side. g_MSB_RIGHT 0 joins it
// on the LSB side. The output uses the registered offset.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module bit_shifter #(
  parameter int unsigned g_DATA_WIDTH = 8,
  parameter bit          g_MSB_RIGHT = 1'b1
) (
  input  logic                                                          clk_i,
  input  logic                                                          reset_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH)))-1:0] offset_i,
  input  logic [g_DATA_WIDTH-1:0]                                       data_i,
  output logic [g_DATA_WIDTH-1:0]                                       data_o
);

  typedef struct packed {
    logic [2*g_DATA_WIDTH-1:0] data_buf;
    int unsigned               offset;
  } reg_t;

  localparam reg_t c_REG_TYPE_INIT = '{data_buf: '0, offset: 0};

  reg_t r = c_REG_TYPE_INIT;
  reg_t rin;

  always_comb begin : proc_comb
    reg_t v;
    v         = r;
    v.offset  = int'(offset_i);
    if (g_MSB_RIGHT)
      v.data_buf = {data_i, r.data_buf[2*g_DATA_WIDTH-1 -: g_DATA_WIDTH]};
    else
      v.data_buf = {r.data_buf[g_DATA_WIDTH-1:0], data_i};

    if (reset_i)
      v = c_REG_TYPE_INIT;

    rin = v;

    if (g_MSB_RIGHT)
      data_o = r.data_buf[(2*g_DATA_WIDTH-1-int'(r.offset)) -: g_DATA_WIDTH];
    else
      data_o = r.data_buf[(int'(r.offset)+g_DATA_WIDTH-1) -: g_DATA_WIDTH];
  end

  always_ff @(posedge clk_i) begin : proc_reg
    r <= rin;
  end

endmodule
