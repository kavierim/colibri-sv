// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Altera-style simple dual-port RAM. Behavioural description for BRAM inference.

`timescale 1ns/1ps

module simple_dpram_altera #(
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
  parameter logic [g_A_DATA_WIDTH-1:0] g_INIT_WORD = '0
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

  localparam int c_MEM_WIDTH  = colibri_utils::minimum(g_A_DATA_WIDTH, g_B_DATA_WIDTH);
  localparam int c_PORT_RATIO = colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) / c_MEM_WIDTH;
  localparam int c_A_RATIO    = g_A_DATA_WIDTH / c_MEM_WIDTH;
  localparam int c_B_RATIO    = g_B_DATA_WIDTH / c_MEM_WIDTH;

  logic [g_B_DATA_WIDTH-1:0] read_b;
  logic [c_MEM_WIDTH-1:0] memory [0:g_N_WORDS-1][0:c_PORT_RATIO-1];

  // Local hex load. Cell 0 remains the MSBs of each hex word.
  initial begin : init_mem
    int fd;
    int code;
    int idx;
    string line;
    logic [c_PORT_RATIO*c_MEM_WIDTH-1:0] flat;
    for (int i = 0; i < g_N_WORDS; i++)
      for (int c = 0; c < c_PORT_RATIO; c++)
        memory[i][c] = c_MEM_WIDTH'(g_INIT_WORD);
    if (g_INIT_FILE != "") begin
      for (int i = 0; i < g_N_WORDS; i++)
        for (int c = 0; c < c_PORT_RATIO; c++)
          memory[i][c] = c_MEM_WIDTH'(0);
      fd = $fopen(g_INIT_FILE, "r");
      if (fd == 0)
        $fatal(1, "init_mem_hex: cannot open %s", g_INIT_FILE);
      idx = 0;
      while (idx < g_N_WORDS) begin
        code = $fgets(line, fd);
        if (code <= 0)
          break;
        if ($sscanf(line, "%h", flat) != 1)
          break;
        for (int c = 0; c < c_PORT_RATIO; c++)
          memory[idx][c] = flat[(c_PORT_RATIO * c_MEM_WIDTH - 1) - (c * c_MEM_WIDTH) -: c_MEM_WIDTH];
        idx++;
      end
      $fclose(fd);
    end
  end

  if (g_A_DATA_WIDTH > g_B_DATA_WIDTH) begin : gen_a_wider
    logic [c_MEM_WIDTH-1:0] wword [0:c_PORT_RATIO-1];
    assign wword = colibri_types::slv_arr#(c_PORT_RATIO, c_MEM_WIDTH)::from_slv(wrdata_i);

    always_ff @(posedge wrclk_i) begin : proc_write_ram_mux
      if (wren_i)
        memory[int'(wraddr_i)] <= wword;
    end
  end else begin : gen_a_direct
    always_ff @(posedge wrclk_i) begin : proc_write_ram_direct
      if (wren_i)
        memory[int'(wraddr_i) / c_PORT_RATIO][int'(wraddr_i) % c_PORT_RATIO] <= wrdata_i;
    end
  end

  if (g_B_DATA_WIDTH > g_A_DATA_WIDTH) begin : gen_b_wider
    logic [c_MEM_WIDTH-1:0] rword [0:c_PORT_RATIO-1];
    assign read_b = colibri_types::slv_arr#(c_PORT_RATIO, c_MEM_WIDTH)::to_slv(rword);

    always_ff @(posedge rdclk_i) begin : proc_read_ram_mux
      if (rden_i)
        rword <= memory[int'(rdaddr_i)];
    end
  end else begin : gen_b_direct
    always_ff @(posedge rdclk_i) begin : proc_read_ram_direct
      if (rden_i)
        read_b <= memory[int'(rdaddr_i) / c_PORT_RATIO][int'(rdaddr_i) % c_PORT_RATIO];
    end
  end

  `COLIBRI_WHEN_REGISTERED(rddata, rdclk_i, g_REGISTER_OUT, rddata_o, read_b)

  if (c_A_RATIO != c_B_RATIO) begin : gen_mixed_width_note
    initial $info("Implementing a Mixed Width (Asymmetric) dual port RAM. Check FPGA datasheet for allowed widths.");
  end

  if ((colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) %
       colibri_utils::minimum(g_A_DATA_WIDTH, g_B_DATA_WIDTH)) != 0) begin : gen_divisor_check
    $error("Smaller port is not a divisor of larger port. Cannot infer RAM with this configuration.");
  end

  if (g_A_ADDR_WIDTH < colibri_utils::log2ceil(g_N_WORDS / c_A_RATIO)) begin : gen_a_addr_check
    $error("The Port A Address width is too small to access g_N_WORDS.");
  end

  if (g_B_ADDR_WIDTH < colibri_utils::log2ceil(g_N_WORDS / c_B_RATIO)) begin : gen_b_addr_check
    $error("The Port B Address width is too small to access g_N_WORDS.");
  end

endmodule
