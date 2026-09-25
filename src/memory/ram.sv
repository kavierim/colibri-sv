// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Single-port RAM. Hex init file, one word per line.
// g_N_WORDS and g_DATA_WIDTH have elaboration defaults; the VHDL generics do not.

`timescale 1ns/1ps

module ram #(
  parameter int g_N_WORDS      = 16,
  parameter int g_DATA_WIDTH   = 8,
  parameter bit g_REGISTER_IN  = 1'b0,
  parameter bit g_REGISTER_OUT = 1'b1,
  parameter string g_INIT_FILE = "",
  parameter logic [g_DATA_WIDTH-1:0] g_INIT_WORD = '0,
  parameter bit g_WRITE_FIRST  = 1'b1
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_i,
  input  logic we_i,
  input  logic [g_DATA_WIDTH-1:0] data_i,
  output logic [g_DATA_WIDTH-1:0] q_o
);

  localparam int c_ADDR_W = colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS));

  logic [g_DATA_WIDTH-1:0] memory [0:g_N_WORDS-1];
  logic [c_ADDR_W-1:0] reg_addr;
  logic reg_we;
  logic [g_DATA_WIDTH-1:0] reg_data;

  // Local hex load. An empty filename fills g_INIT_WORD.
  initial begin : init_mem
    int fd;
    if (g_INIT_FILE == "") begin
      for (int i = 0; i < g_N_WORDS; i++)
        memory[i] = g_INIT_WORD;
    end else begin
      for (int i = 0; i < g_N_WORDS; i++)
        memory[i] = g_DATA_WIDTH'(0);
      fd = $fopen(g_INIT_FILE, "r");
      if (fd == 0)
        $fatal(1, "init_mem_hex: cannot open %s", g_INIT_FILE);
      $fclose(fd);
      $readmemh(g_INIT_FILE, memory);
    end
  end

  `COLIBRI_WHEN_REGISTERED(reg_addr, clk_i, g_REGISTER_IN, reg_addr, addr_i)
  `COLIBRI_WHEN_REGISTERED(reg_we, clk_i, g_REGISTER_IN, reg_we, we_i)
  `COLIBRI_WHEN_REGISTERED(reg_data, clk_i, g_REGISTER_IN, reg_data, data_i)

  if (g_REGISTER_OUT) begin : gen_async_read
    logic [g_DATA_WIDTH-1:0] reg_q;

    always_ff @(posedge clk_i) begin : proc_ram
      if (reg_we)
        memory[reg_addr] <= reg_data;
      if (reset_i)
        reg_q <= '0;
      else if (g_WRITE_FIRST && reg_we)
        reg_q <= reg_data;
      else
        reg_q <= memory[reg_addr];
    end

    assign q_o = reg_q;
  end else begin : gen_comb_read
    always_ff @(posedge clk_i) begin : proc_ram
      if (reg_we)
        memory[reg_addr] <= reg_data;
    end

    assign q_o = (g_WRITE_FIRST && reg_we) ? reg_data : memory[reg_addr];
  end

endmodule
