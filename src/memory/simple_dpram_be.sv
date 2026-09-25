// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple dual-port RAM with a write byte-enable.
// g_WORD_BYTES and g_N_WORDS have elaboration defaults; the VHDL generics do not.

`timescale 1ns/1ps

// The memory file list elaborates every uninstantiated module together with
// wave0_elab. Verilator -Wall treats that as MULTITOP.
// verilator lint_off MULTITOP
module simple_dpram_be #(
  parameter int g_BYTE_WIDTH = 8,
  parameter int g_WORD_BYTES = 4,
  parameter int g_N_WORDS    = 16,
  parameter string g_INIT_FILE = "",
  parameter logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] g_INIT_WORD = '0
) (
  input  logic wrclk_i,
  input  logic [g_WORD_BYTES-1:0] wren_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] wraddr_i,
  input  logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] wrdata_i,
  input  logic rdclk_i,
  input  logic rden_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] rdaddr_i,
  output logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] rddata_o
);

  localparam int c_DATA_WIDTH = g_WORD_BYTES * g_BYTE_WIDTH;

  logic [c_DATA_WIDTH-1:0] memory [0:g_N_WORDS-1];

  // Local hex load. An empty filename fills g_INIT_WORD.
  initial begin : init_mem
    int fd;
    if (g_INIT_FILE == "") begin
      for (int i = 0; i < g_N_WORDS; i++)
        memory[i] = g_INIT_WORD;
    end else begin
      for (int i = 0; i < g_N_WORDS; i++)
        memory[i] = c_DATA_WIDTH'(0);
      fd = $fopen(g_INIT_FILE, "r");
      if (fd == 0)
        $fatal(1, "init_mem_hex: cannot open %s", g_INIT_FILE);
      $fclose(fd);
      $readmemh(g_INIT_FILE, memory);
    end
  end

  always_ff @(posedge wrclk_i) begin : proc_write_ram
    for (int i = 0; i < g_WORD_BYTES; i++) begin
      if (wren_i[i])
        memory[int'(wraddr_i)][i*g_BYTE_WIDTH +: g_BYTE_WIDTH] <=
          wrdata_i[i*g_BYTE_WIDTH +: g_BYTE_WIDTH];
    end
  end

  always_ff @(posedge rdclk_i) begin : proc_read_ram
    if (rden_i)
      rddata_o <= memory[int'(rdaddr_i)];
  end

endmodule
