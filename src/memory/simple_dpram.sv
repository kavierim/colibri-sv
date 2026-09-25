// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple Dual-Port RAM.
// A signal or shared-variable memory is a logic array updated in always_ff.
// simple_dpram_xilinx is that model, and it is the one selected when
// g_IMPL_STYLE is not QUARTUS (including Verilator, where get_compiler is AUTO).

`timescale 1ns/1ps

module simple_dpram #(
  parameter int g_DATA_WIDTH   = 16,
  parameter int g_A_DATA_WIDTH = g_DATA_WIDTH,
  parameter int g_B_DATA_WIDTH = g_A_DATA_WIDTH,
  parameter int g_N_WORDS      = 10,
  parameter int g_A_ADDR_WIDTH = colibri_utils::log2ceil(
    colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) * g_N_WORDS / g_A_DATA_WIDTH
  ),
  parameter int g_B_ADDR_WIDTH = colibri_utils::log2ceil(
    colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) * g_N_WORDS / g_B_DATA_WIDTH
  ),
  parameter bit g_REGISTER_OUT = 1'b0,
  parameter string g_INIT_FILE = "",
  parameter logic [g_A_DATA_WIDTH-1:0] g_INIT_WORD = '0,
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic wrclk_i,
  input  logic wren_i,
  input  logic [colibri_utils::downto_width(g_A_ADDR_WIDTH)-1:0] wraddr_i,
  input  logic [g_A_DATA_WIDTH-1:0] wrdata_i,
  input  logic rdclk_i,
  input  logic rden_i,
  input  logic [colibri_utils::downto_width(g_B_ADDR_WIDTH)-1:0] rdaddr_i,
  output logic [g_B_DATA_WIDTH-1:0] rddata_o
);

  if (g_IMPL_STYLE == colibri_utils::QUARTUS) begin : gen_impl_style
    simple_dpram_altera #(
      .g_DATA_WIDTH(g_DATA_WIDTH),
      .g_A_DATA_WIDTH(g_A_DATA_WIDTH),
      .g_B_DATA_WIDTH(g_B_DATA_WIDTH),
      .g_N_WORDS(g_N_WORDS),
      .g_A_ADDR_WIDTH(g_A_ADDR_WIDTH),
      .g_B_ADDR_WIDTH(g_B_ADDR_WIDTH),
      .g_REGISTER_OUT(g_REGISTER_OUT)
    ) simple_dpram_altera_inst (
      .wrclk_i(wrclk_i),
      .wren_i(wren_i),
      .wraddr_i(wraddr_i),
      .wrdata_i(wrdata_i),
      .rdclk_i(rdclk_i),
      .rden_i(rden_i),
      .rdaddr_i(rdaddr_i),
      .rddata_o(rddata_o)
    );
  end else begin : gen_impl_xilinx
    simple_dpram_xilinx #(
      .g_DATA_WIDTH(g_DATA_WIDTH),
      .g_A_DATA_WIDTH(g_A_DATA_WIDTH),
      .g_B_DATA_WIDTH(g_B_DATA_WIDTH),
      .g_N_WORDS(g_N_WORDS),
      .g_A_ADDR_WIDTH(g_A_ADDR_WIDTH),
      .g_B_ADDR_WIDTH(g_B_ADDR_WIDTH),
      .g_REGISTER_OUT(g_REGISTER_OUT),
      .g_INIT_FILE(g_INIT_FILE),
      .g_INIT_WORD(g_INIT_WORD)
    ) simple_dpram_xilinx_inst (
      .wrclk_i(wrclk_i),
      .wren_i(wren_i),
      .wraddr_i(wraddr_i),
      .wrdata_i(wrdata_i),
      .rdclk_i(rdclk_i),
      .rden_i(rden_i),
      .rdaddr_i(rdaddr_i),
      .rddata_o(rddata_o)
    );
  end

endmodule
