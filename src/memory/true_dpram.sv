// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// True dual-port RAM with mixed-width support.
// The selected model stores the array as logic and updates it in always_ff.

`timescale 1ns/1ps

module true_dpram #(
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
  parameter bit g_WRITE_FIRST  = 1'b0,
  parameter bit g_REGISTER_OUT = 1'b0,
  parameter string g_INIT_FILE = "",
  parameter logic [g_DATA_WIDTH-1:0] g_INIT_WORD = '0,
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic clka_i,
  input  logic wra_i,
  input  logic [colibri_utils::downto_width(g_A_ADDR_WIDTH)-1:0] addra_i,
  input  logic [g_A_DATA_WIDTH-1:0] dataa_i,
  output logic [g_A_DATA_WIDTH-1:0] dataa_o,
  input  logic clkb_i,
  input  logic wrb_i,
  input  logic [colibri_utils::downto_width(g_B_ADDR_WIDTH)-1:0] addrb_i,
  input  logic [g_B_DATA_WIDTH-1:0] datab_i,
  output logic [g_B_DATA_WIDTH-1:0] datab_o
);

  if (g_IMPL_STYLE == colibri_utils::QUARTUS) begin : gen_impl
    true_dpram_altera #(
      .g_DATA_WIDTH(g_DATA_WIDTH),
      .g_A_DATA_WIDTH(g_A_DATA_WIDTH),
      .g_B_DATA_WIDTH(g_B_DATA_WIDTH),
      .g_N_WORDS(g_N_WORDS),
      .g_A_ADDR_WIDTH(g_A_ADDR_WIDTH),
      .g_B_ADDR_WIDTH(g_B_ADDR_WIDTH),
      .g_REGISTER_OUT(g_REGISTER_OUT)
    ) true_dpram_altera_inst (
      .clka_i(clka_i),
      .wra_i(wra_i),
      .addra_i(addra_i),
      .dataa_i(dataa_i),
      .dataa_o(dataa_o),
      .clkb_i(clkb_i),
      .wrb_i(wrb_i),
      .addrb_i(addrb_i),
      .datab_i(datab_i),
      .datab_o(datab_o)
    );
  end else begin : gen_impl_xilinx
    true_dpram_xilinx #(
      .g_DATA_WIDTH(g_DATA_WIDTH),
      .g_A_DATA_WIDTH(g_A_DATA_WIDTH),
      .g_B_DATA_WIDTH(g_B_DATA_WIDTH),
      .g_N_WORDS(g_N_WORDS),
      .g_A_ADDR_WIDTH(g_A_ADDR_WIDTH),
      .g_B_ADDR_WIDTH(g_B_ADDR_WIDTH),
      .g_WRITE_FIRST(g_WRITE_FIRST),
      .g_REGISTER_OUT(g_REGISTER_OUT),
      .g_INIT_FILE(g_INIT_FILE),
      .g_INIT_WORD(g_INIT_WORD)
    ) true_dpram_xilinx_inst (
      .clka_i(clka_i),
      .wra_i(wra_i),
      .addra_i(addra_i),
      .dataa_i(dataa_i),
      .dataa_o(dataa_o),
      .clkb_i(clkb_i),
      .wrb_i(wrb_i),
      .addrb_i(addrb_i),
      .datab_i(datab_i),
      .datab_o(datab_o)
    );
  end

endmodule
