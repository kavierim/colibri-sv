// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Xilinx-style true dual-port RAM. Behavioural description for BRAM inference.
// The VHDL shared variable is a logic array. Both ports update it in always_ff.

`timescale 1ns/1ps

module true_dpram_xilinx #(
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
  parameter bit g_WRITE_FIRST  = 1'b1,
  parameter bit g_REGISTER_OUT = 1'b0,
  parameter string g_INIT_FILE = "",
  parameter logic [g_DATA_WIDTH-1:0] g_INIT_WORD = '0
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

  localparam int c_MEM_WIDTH  = colibri_utils::minimum(g_A_DATA_WIDTH, g_B_DATA_WIDTH);
  localparam int c_PORT_RATIO = colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) / c_MEM_WIDTH;
  localparam int c_MEM_DEPTH  = g_N_WORDS * c_PORT_RATIO;
  localparam int c_A_RATIO    = g_A_DATA_WIDTH / c_MEM_WIDTH;
  localparam int c_B_RATIO    = g_B_DATA_WIDTH / c_MEM_WIDTH;

  logic [g_A_DATA_WIDTH-1:0] read_a;
  logic [g_B_DATA_WIDTH-1:0] read_b;

  // verilator lint_off MULTIDRIVEN
  logic [c_MEM_WIDTH-1:0] memory [0:c_MEM_DEPTH-1];
  // Local hex load. An empty filename fills g_INIT_WORD.
  initial begin : init_mem
    int fd;
    if (g_INIT_FILE == "") begin
      for (int i = 0; i < c_MEM_DEPTH; i++)
        memory[i] = c_MEM_WIDTH'(g_INIT_WORD);
    end else begin
      for (int i = 0; i < c_MEM_DEPTH; i++)
        memory[i] = c_MEM_WIDTH'(0);
      fd = $fopen(g_INIT_FILE, "r");
      if (fd == 0)
        $fatal(1, "init_mem_hex: cannot open %s", g_INIT_FILE);
      $fclose(fd);
      $readmemh(g_INIT_FILE, memory);
    end
  end

  if (g_A_DATA_WIDTH > g_B_DATA_WIDTH) begin : gen_a_wider
    localparam int c_A_LSB_W = colibri_utils::log2ceil(c_A_RATIO);

    if (g_WRITE_FIRST) begin : gen_a_write_first
      always_ff @(posedge clka_i) begin : proc_port_a_mux
        if (wra_i) begin
          for (int i = 0; i < c_A_RATIO; i++)
            memory[int'({addra_i, c_A_LSB_W'(i)})] <=
              dataa_i[(g_A_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH];
          read_a <= dataa_i;
        end else begin
          logic [g_A_DATA_WIDTH-1:0] v_word;
          v_word = read_a;
          for (int i = 0; i < c_A_RATIO; i++)
            v_word[(g_A_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH] =
              memory[int'({addra_i, c_A_LSB_W'(i)})];
          read_a <= v_word;
        end
      end
    end else begin : gen_a_read_first
      always_ff @(posedge clka_i) begin : proc_port_a_mux
        logic [g_A_DATA_WIDTH-1:0] v_word;
        v_word = read_a;
        for (int i = 0; i < c_A_RATIO; i++) begin
          v_word[(g_A_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH] =
            memory[int'({addra_i, c_A_LSB_W'(i)})];
          if (wra_i)
            memory[int'({addra_i, c_A_LSB_W'(i)})] <=
              dataa_i[(g_A_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH];
        end
        read_a <= v_word;
      end
    end
  end else begin : gen_a_direct
    if (g_WRITE_FIRST) begin : gen_a_write_first
      always_ff @(posedge clka_i) begin : proc_port_a_direct
        if (wra_i) begin
          memory[int'(addra_i)] <= dataa_i;
          read_a <= dataa_i;
        end else begin
          read_a <= memory[int'(addra_i)];
        end
      end
    end else begin : gen_a_read_first
      always_ff @(posedge clka_i) begin : proc_port_a_direct
        read_a <= memory[int'(addra_i)];
        if (wra_i)
          memory[int'(addra_i)] <= dataa_i;
      end
    end
  end

  if (g_B_DATA_WIDTH > g_A_DATA_WIDTH) begin : gen_b_wider
    localparam int c_B_LSB_W = colibri_utils::log2ceil(c_B_RATIO);

    if (g_WRITE_FIRST) begin : gen_b_write_first
      always_ff @(posedge clkb_i) begin : proc_port_b_mux
        if (wrb_i) begin
          for (int i = 0; i < c_B_RATIO; i++)
            memory[int'({addrb_i, c_B_LSB_W'(i)})] <=
              datab_i[(g_B_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH];
          read_b <= datab_i;
        end else begin
          logic [g_B_DATA_WIDTH-1:0] v_word;
          v_word = read_b;
          for (int i = 0; i < c_B_RATIO; i++)
            v_word[(g_B_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH] =
              memory[int'({addrb_i, c_B_LSB_W'(i)})];
          read_b <= v_word;
        end
      end
    end else begin : gen_b_read_first
      always_ff @(posedge clkb_i) begin : proc_port_b_mux
        logic [g_B_DATA_WIDTH-1:0] v_word;
        v_word = read_b;
        for (int i = 0; i < c_B_RATIO; i++) begin
          v_word[(g_B_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH] =
            memory[int'({addrb_i, c_B_LSB_W'(i)})];
          if (wrb_i)
            memory[int'({addrb_i, c_B_LSB_W'(i)})] <=
              datab_i[(g_B_DATA_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH];
        end
        read_b <= v_word;
      end
    end
  end else begin : gen_b_direct
    if (g_WRITE_FIRST) begin : gen_b_write_first
      always_ff @(posedge clkb_i) begin : proc_port_b_direct
        if (wrb_i) begin
          memory[int'(addrb_i)] <= datab_i;
          read_b <= datab_i;
        end else begin
          read_b <= memory[int'(addrb_i)];
        end
      end
    end else begin : gen_b_read_first
      always_ff @(posedge clkb_i) begin : proc_port_b_direct
        read_b <= memory[int'(addrb_i)];
        if (wrb_i)
          memory[int'(addrb_i)] <= datab_i;
      end
    end
  end
  // verilator lint_on MULTIDRIVEN

  `COLIBRI_WHEN_REGISTERED(dataa, clka_i, g_REGISTER_OUT, dataa_o, read_a)
  `COLIBRI_WHEN_REGISTERED(datab, clkb_i, g_REGISTER_OUT, datab_o, read_b)

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
