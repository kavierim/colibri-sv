// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Read-only memory. Contents come from a hex file, one word per line.
// g_N_WORDS and g_DATA_WIDTH have elaboration defaults; the VHDL generics do not.

`timescale 1ns/1ps

module rom #(
  parameter int g_N_WORDS    = 16,
  parameter int g_DATA_WIDTH = 8,
  parameter string g_INIT_FILE = ""
) (
  input  logic clk_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_i,
  output logic [g_DATA_WIDTH-1:0] data_o
);

  logic [g_DATA_WIDTH-1:0] memory [0:g_N_WORDS-1];

  // Local hex load. An empty file stays 0, one word per line.
  // $fgets keeps a final line that has no trailing newline.
  initial begin : init_mem
    int fd;
    int code;
    int idx;
    string line;
    logic [g_DATA_WIDTH-1:0] word;
    for (int i = 0; i < g_N_WORDS; i++)
      memory[i] = g_DATA_WIDTH'(0);
    if (g_INIT_FILE != "") begin
      fd = $fopen(g_INIT_FILE, "r");
      if (fd == 0)
        $fatal(1, "init_mem_hex: cannot open %s", g_INIT_FILE);
      idx = 0;
      while (idx < g_N_WORDS) begin
        code = $fgets(line, fd);
        if (code <= 0)
          break;
        if ($sscanf(line, "%h", word) == 1) begin
          memory[idx] = word;
          idx++;
        end
      end
      $fclose(fd);
    end
  end

  always_ff @(posedge clk_i) begin : proc_read
    data_o <= memory[int'(addr_i)];
  end

endmodule
