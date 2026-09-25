// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Single-clock gearbox. Input and output widths are independent.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module gearbox #(
  // VHDL leaves both widths without a default. Verilator will not elaborate
  // a parameter that has no initial value, so both default to 8.
  parameter int g_INPUT_WIDTH = 8,
  parameter int g_OUTPUT_WIDTH = 8
) (
  input  logic                     clk_i,
  input  logic                     reset_i,
  input  logic [g_INPUT_WIDTH-1:0] snk_data_i,
  input  logic                     snk_valid_i,
  output logic                     snk_ready_o,
  output logic [g_OUTPUT_WIDTH-1:0] src_data_o,
  output logic                     src_valid_o,
  input  logic                     src_ready_i
);

  localparam int c_BUF_SIZE = 2 * colibri_utils::maximum(g_OUTPUT_WIDTH, g_INPUT_WIDTH)
    + colibri_utils::minimum(g_OUTPUT_WIDTH, g_INPUT_WIDTH);

  logic [c_BUF_SIZE-1:0]    buf_bits = '0;
  logic                     empty;
  logic                     full;
  int unsigned              usedb = 0;
  logic                     cmb_valid;
  logic                     reg_valid = 1'b0;
  logic                     int_ready;
  logic [g_OUTPUT_WIDTH-1:0] int_data = '0;

  assign snk_ready_o = ~full & ~reset_i;
  assign full        = usedb > (c_BUF_SIZE - g_INPUT_WIDTH);
  assign empty       = usedb < g_OUTPUT_WIDTH;

  always_ff @(posedge clk_i) begin : proc_ptr
    int unsigned v_used;
    if (reset_i) begin
      usedb <= 0;
    end else begin
      v_used = usedb;
      if (snk_valid_i && !full)
        v_used = v_used + int'(g_INPUT_WIDTH);
      if (!empty && int_ready)
        v_used = v_used - int'(g_OUTPUT_WIDTH);
      usedb <= v_used;
    end
  end

  always_ff @(posedge clk_i) begin : proc_wr_data
    if (!reset_i && snk_valid_i && !full)
      buf_bits <= {buf_bits[c_BUF_SIZE-1-g_INPUT_WIDTH:0], snk_data_i};
  end

  always_ff @(posedge clk_i) begin : proc_rd_data
    if (!reset_i && !empty && int_ready) begin
      for (int i = g_OUTPUT_WIDTH; i <= c_BUF_SIZE; i++) begin
        if (i == int'(usedb))
          int_data <= buf_bits[i-1 -: g_OUTPUT_WIDTH];
      end
    end
  end

  always_comb begin : proc_buffer
    logic v_valid;
    v_valid = reg_valid;
    if (src_ready_i && reg_valid)
      v_valid = 1'b0;
    if (!empty && !v_valid) begin
      int_ready = 1'b1;
      v_valid   = 1'b1;
    end else begin
      int_ready = 1'b0;
    end
    if (reset_i)
      v_valid = 1'b0;
    cmb_valid = v_valid;
  end

  always_ff @(posedge clk_i) begin : proc_reg_valid
    reg_valid <= cmb_valid;
  end

  assign src_valid_o = reg_valid;
  assign src_data_o  = reg_valid ? int_data : '0;

endmodule
