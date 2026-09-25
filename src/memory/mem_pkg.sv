// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// VHDL package `mem` (file mem_pkg.vhdl) is SystemVerilog package `colibri_mem`.
// Unread words are 0. VHDL left those locations 'U' on a short file.
// Pass `WORD'(init_word)` or `CELL'(init_word)` at the call site. That cast is
// unsigned resize: LSBs are kept, a narrower source is zero-extended.

`timescale 1ns/1ps

package colibri_mem;

  class hexword #(parameter int BIT_W = 8);
    // One textio HREAD: exactly ceil(BIT_W/4) hex digits, value must fit in BIT_W.
    static function automatic bit parse_line(input string line, output logic [BIT_W-1:0] value);
      int need;
      int got;
      int cv;
      logic [3:0] nibble;
      byte c;
      logic [BIT_W+3:0] acc;
      need  = (BIT_W + 3) / 4;
      got   = 0;
      acc   = '0;
      value = '0;
      for (int idx = 0; idx < line.len(); idx++) begin
        c = line[idx];
        if ((c == 8'h20) || (c == 8'h09) || (c == 8'h0a) || (c == 8'h0d) || (c == 8'h5f))
          continue;
        cv = int'(c);
        if ((cv >= 48) && (cv <= 57))
          nibble = 4'(cv - 48);
        else if ((cv >= 97) && (cv <= 102))
          nibble = 4'(cv - 87);
        else if ((cv >= 65) && (cv <= 70))
          nibble = 4'(cv - 55);
        else
          return 1'b0;
        acc = (acc << 4) | (BIT_W + 4)'(nibble);
        got++;
        if (got == need)
          break;
      end
      if (got != need)
        return 1'b0;
      if (acc >= ((BIT_W + 4)'(1) << BIT_W))
        return 1'b0;
      value = acc[BIT_W-1:0];
      return 1'b1;
    endfunction
  endclass

  // VHDL init_mem_hex(filename, word_size, ram_size, init_word) -> slv_array_t.
  class flat #(parameter int WORD_SIZE = 8, parameter int RAM_SIZE = 1);
    typedef logic [WORD_SIZE-1:0] word_t;
    typedef word_t mem_t [0:RAM_SIZE-1];

    static function automatic mem_t init_mem_hex(input string filename, input word_t init_word);
      mem_t v_ram;
      int fd;
      int idx;
      int code;
      string line;
      word_t v_word;
      for (int i = 0; i < RAM_SIZE; i++)
        v_ram[i] = '0;
      if (filename == "") begin
        for (int i = 0; i < RAM_SIZE; i++)
          v_ram[i] = init_word;
        return v_ram;
      end
      fd = $fopen(filename, "r");
      if (fd == 0) begin
        $fatal(1, "init_mem_hex: cannot open %s", filename);
        return v_ram;
      end
      idx = 0;
      while (idx < RAM_SIZE) begin
        code = $fgets(line, fd);
        if (code <= 0)
          break;
        if (!hexword#(WORD_SIZE)::parse_line(line, v_word))
          break;
        v_ram[idx] = v_word;
        idx++;
      end
      $fclose(fd);
      return v_ram;
    endfunction
  endclass

  // VHDL init_mem_hex(filename, cell_size, word_size, ram_size, init_word) -> slv_array_2d_t.
  // Cell 0 of each word is the MSBs of the hex word, matching slv_to_slv_array.
  class grid #(
    parameter int CELL_SIZE = 8,
    parameter int WORD_SIZE = 1,
    parameter int RAM_SIZE  = 1
  );
    typedef logic [CELL_SIZE-1:0] cell_t;
    typedef cell_t word_t [0:WORD_SIZE-1];
    typedef word_t mem_t [0:RAM_SIZE-1];
    localparam int FLAT_W = WORD_SIZE * CELL_SIZE;

    static function automatic mem_t init_mem_hex(input string filename, input cell_t init_word);
      mem_t v_ram;
      int fd;
      int idx;
      int code;
      string line;
      logic [FLAT_W-1:0] v_flat;
      for (int i = 0; i < RAM_SIZE; i++) begin
        for (int c = 0; c < WORD_SIZE; c++)
          v_ram[i][c] = '0;
      end
      if (filename == "") begin
        for (int i = 0; i < RAM_SIZE; i++) begin
          for (int c = 0; c < WORD_SIZE; c++)
            v_ram[i][c] = init_word;
        end
        return v_ram;
      end
      fd = $fopen(filename, "r");
      if (fd == 0) begin
        $fatal(1, "init_mem_hex: cannot open %s", filename);
        return v_ram;
      end
      idx = 0;
      while (idx < RAM_SIZE) begin
        code = $fgets(line, fd);
        if (code <= 0)
          break;
        if (!hexword#(FLAT_W)::parse_line(line, v_flat))
          break;
        for (int c = 0; c < WORD_SIZE; c++)
          v_ram[idx][c] = v_flat[(FLAT_W - 1) - (c * CELL_SIZE) -: CELL_SIZE];
        idx++;
      end
      $fclose(fd);
      return v_ram;
    endfunction
  endclass

endpackage
