// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-synchronous scrambler.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module scrambler #(
  parameter int unsigned g_DATA_WIDTH = 64,
  // Polynomial. x^0 is ignored. MSB is to the right.
  parameter g_SCRAMBLER_POLY = colibri_poly::c_SCR_10GBASE,
  // VHDL gen_even: even indexes are 1, and index 0 is the LSB.
  // Class methods are not legal in a parameter expression. The pattern is
  // periodic, so the low polynomial-width bits are gen_even for widths <= 8192.
  parameter g_INIT_VAL = $bits(g_SCRAMBLER_POLY)'({4096{2'b01}}),
  parameter bit g_INVERT_IN = 1'b1,
  parameter bit g_INVERT_OUT = 1'b1
) (
  input  logic                    clk_i,
  input  logic                    reset_i,      // active high
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic                    snk_valid_i,
  output logic                    snk_ready_o,
  output logic                    src_valid_o,
  input  logic                    src_ready_i,
  output logic [g_DATA_WIDTH-1:0] src_data_o
);

  localparam int c_POLY_W = $bits(g_SCRAMBLER_POLY);
  localparam int c_REGISTER_WIDTH = c_POLY_W + int'(g_DATA_WIDTH);

  if ($bits(g_INIT_VAL) != c_POLY_W) begin : gen_init_len
    $error("ERROR: Init Value has to match Polynomial length");
  end

  logic [c_REGISTER_WIDTH-1:0] shift_reg;
  logic                        tmpi_valid;
  logic                        tmpo_valid;
  logic                        tmpo_ready;
  logic                        tmpi_ready;
  logic [g_DATA_WIDTH-1:0]     tmpi_data;
  logic [g_DATA_WIDTH-1:0]     tmpr_data;
  logic [g_DATA_WIDTH-1:0]     o_data;
  logic                        reg_valid = 1'b0;
  logic                        cmb_valid;
  logic [g_DATA_WIDTH-1:0]     reg_data = '0;

  // Local bit reverse. bits#(W) for a non-byte W makes Verilator 5.020 emit
  // C++ that does not compile, via the unused swap_endianness method.
  function automatic logic [g_DATA_WIDTH-1:0] invert_word(input logic [g_DATA_WIDTH-1:0] word);
    logic [g_DATA_WIDTH-1:0] v_res;
    for (int i = 0; i < g_DATA_WIDTH; i++)
      v_res[i] = word[g_DATA_WIDTH - 1 - i];
    return v_res;
  endfunction

  if (g_INVERT_IN) begin : gen_invert_in
    assign tmpi_data = invert_word(snk_data_i);
  end else begin : gen_pass_in
    assign tmpi_data = snk_data_i;
  end

  if (g_INVERT_OUT) begin : gen_invert_out
    assign o_data = invert_word(tmpr_data);
  end else begin : gen_pass_out
    assign o_data = tmpr_data;
  end

  assign tmpi_valid  = snk_valid_i;
  assign tmpr_data   = shift_reg[c_REGISTER_WIDTH-1 -: g_DATA_WIDTH];
  assign snk_ready_o = tmpi_ready;
  assign tmpi_ready  = tmpo_ready;

  always_ff @(posedge clk_i) begin : proc_shift_register
    logic [c_REGISTER_WIDTH-1:0] v_reg;
    logic                        v_xorbit;

    tmpo_valid <= 1'b0;
    if (reset_i) begin
      shift_reg[c_REGISTER_WIDTH-1:g_DATA_WIDTH] <= g_INIT_VAL;
    end else if (tmpi_valid && tmpi_ready) begin
      v_reg = shift_reg;
      for (int i = 0; i < g_DATA_WIDTH; i++) begin
        v_xorbit = ^(v_reg[c_REGISTER_WIDTH-1:g_DATA_WIDTH] & g_SCRAMBLER_POLY)
                   ^ tmpi_data[i];
        v_reg = {v_xorbit, v_reg[c_REGISTER_WIDTH-1:1]};
      end
      shift_reg  <= v_reg;
      tmpo_valid <= 1'b1;
    end
  end

  assign tmpo_ready = src_ready_i | ~cmb_valid;

  always_ff @(posedge clk_i) begin : proc_reg_out
    if (reset_i) begin
      reg_valid <= 1'b0;
    end else begin
      if (!src_ready_i && !reg_valid) begin
        reg_valid <= tmpo_valid;
        reg_data  <= o_data;
      end
      if (src_ready_i && reg_valid)
        reg_valid <= 1'b0;
    end
  end

  assign src_data_o  = reg_valid ? reg_data : o_data;
  assign cmb_valid   = tmpo_valid | reg_valid;
  assign src_valid_o = cmb_valid;

endmodule
