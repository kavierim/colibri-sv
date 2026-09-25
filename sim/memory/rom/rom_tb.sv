// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/rom/rom_tb.vhdl.
// Walks every address and compares the registered output with the hex file.

`timescale 1ns/1ps

module rom_tb;

  localparam int g_N_WORDS    = 20;
  localparam int g_DATA_WIDTH = 32;
  localparam int c_ADDR_W     = colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS));
  localparam string c_INIT_FILE = "../colibri/sim/memory/rom/rom_contents.txt";

  logic clk = 1'b0;
  logic [c_ADDR_W-1:0] addr = '0;
  logic [g_DATA_WIDTH-1:0] data;

  always #5 clk = ~clk;

  rom #(
    .g_N_WORDS(g_N_WORDS),
    .g_DATA_WIDTH(g_DATA_WIDTH),
    .g_INIT_FILE(c_INIT_FILE)
  ) uut_rom (
    .clk_i(clk),
    .addr_i(addr),
    .data_o(data)
  );

  logic [g_DATA_WIDTH-1:0] expect_mem [0:g_N_WORDS-1];

  initial begin
    int fd;
    int code;
    string line;
    logic [g_DATA_WIDTH-1:0] word;
    fd = $fopen(c_INIT_FILE, "r");
    if (fd == 0)
      $fatal(1, "rom_tb: cannot open %s", c_INIT_FILE);
    for (int i = 0; i < g_N_WORDS; i++) begin
      code = $fgets(line, fd);
      if (code <= 0)
        $fatal(1, "rom_tb: short init file at %0d", i);
      if ($sscanf(line, "%h", word) != 1)
        $fatal(1, "rom_tb: bad hex line %s", line);
      expect_mem[i] = word;
    end
    $fclose(fd);

    for (int i = 0; i < g_N_WORDS; i++) begin
      @(negedge clk);
      addr = c_ADDR_W'(i);
      @(posedge clk);
      #1;
      if (data !== expect_mem[i])
        $fatal(1, "rom_tb: addr %0d got %h exp %h", i, data, expect_mem[i]);
    end
    $display("PASS rom_tb");
    $finish;
  end

  initial begin
    #10_000;
    $fatal(1, "rom_tb: timeout");
  end

endmodule
