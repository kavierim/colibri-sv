// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Binary file I/O testbench.
// Translated from sim/fileio/binaryio_tb.vhdl.
//
// test_alive: write one vector and read it back (entity default g_READ_BYTES = 16).
// test_incomplete: stream the same layout for g_READ_BYTES 4..32, matching
// sim/fileio/run.py. The last word is a short read; empty bytes sit at the LSB.

`timescale 1ns/1ps

module binaryio_tb;

  localparam string c_FILE = "sim/fileio/testfile.bin";
  localparam int c_ALIVE_READ_BYTES  = 16;
  localparam int c_ALIVE_WRITE_BYTES = 31 * c_ALIVE_READ_BYTES + c_ALIVE_READ_BYTES / 3;
  localparam int c_ALIVE_VEC_W       = 8 * c_ALIVE_WRITE_BYTES;

  // 0 until test_alive finishes, then 1..30 as each incomplete width finishes.
  int phase = 0;

  logic [c_ALIVE_VEC_W-1:0] alive_vec;
  logic [c_ALIVE_VEC_W-1:0] alive_readback;

  function automatic logic [7:0] byte_pattern(input int byte_index, input int read_bytes);
    logic [7:0] raw;
    raw = 8'(byte_index * 17 + read_bytes);
    return raw ^ 8'hA5;
  endfunction

  // Mode must be a string literal. Verilator rejects a string variable here.
  task automatic open_write(output colibri_binaryio::binary_file_t bin_file);
    bin_file = $fopen(c_FILE, "wb");
    if (bin_file == 0)
      $fatal(1, "file_open failed mode wb path %s", c_FILE);
  endtask

  task automatic open_read(output colibri_binaryio::binary_file_t bin_file);
    bin_file = $fopen(c_FILE, "rb");
    if (bin_file == 0)
      $fatal(1, "file_open failed mode rb path %s", c_FILE);
  endtask

  initial begin : proc_alive
    colibri_binaryio::binary_file_t bin_file;

    for (int b = 0; b < c_ALIVE_WRITE_BYTES; b++)
      alive_vec[c_ALIVE_VEC_W - 1 - (8 * b) -: 8] = byte_pattern(b, c_ALIVE_READ_BYTES);

    open_write(bin_file);
    colibri_binaryio::binword#(c_ALIVE_VEC_W)::write(bin_file, alive_vec);
    #1ns;
    $fclose(bin_file);

    open_read(bin_file);
    colibri_binaryio::binword#(c_ALIVE_VEC_W)::read_full(bin_file, alive_readback);
    #1ns;
    $fclose(bin_file);

    if (alive_readback != alive_vec)
      $fatal(1, "test_alive: Expected read values to match the written ones. Expected %h Received %h",
             alive_vec, alive_readback);

    $display("test_alive: PASS");
    phase = 1;
  end

  for (genvar gb = 4; gb <= 32; gb++) begin : gen_incomplete
    localparam int g_READ_BYTES  = gb;
    localparam int c_WRITE_BYTES = 31 * g_READ_BYTES + g_READ_BYTES / 3;
    localparam int c_READ_WORDS  = colibri_utils::div_ceil(c_WRITE_BYTES, g_READ_BYTES);
    localparam int c_VEC_W       = 8 * c_WRITE_BYTES;
    localparam int c_WORD_W      = 8 * g_READ_BYTES;
    localparam int c_LAST_EMPTY  = g_READ_BYTES - (c_WRITE_BYTES % g_READ_BYTES);
    localparam int c_TAIL_BITS   = c_WORD_W - (8 * c_LAST_EMPTY);
    localparam int c_TAIL_HI     = c_VEC_W - 1 - (8 * (c_READ_WORDS - 1) * g_READ_BYTES);
    localparam int c_TAIL_LO     = c_VEC_W - (8 * (c_READ_WORDS * g_READ_BYTES - c_LAST_EMPTY));

    logic [c_VEC_W-1:0]  test_vec;
    logic [c_WORD_W-1:0] read_stream;
    logic [c_WORD_W-1:0] expected;

    if ((c_TAIL_BITS < 8) || (c_TAIL_BITS >= c_WORD_W) || (c_TAIL_LO != 0)
        || ((c_TAIL_HI - c_TAIL_LO + 1) != c_TAIL_BITS)) begin : gen_bad_tail
      initial $fatal(1, "test_incomplete: tail slice does not match the VHDL index formula");
    end

    initial begin : proc_incomplete
      colibri_binaryio::binary_file_t bin_file;
      int unsigned empty;
      int src_hi;

      wait (phase == (g_READ_BYTES - 3));

      for (int b = 0; b < c_WRITE_BYTES; b++)
        test_vec[c_VEC_W - 1 - (8 * b) -: 8] = byte_pattern(b, g_READ_BYTES);

      open_write(bin_file);
      colibri_binaryio::binword#(c_VEC_W)::write(bin_file, test_vec);
      #1ns;
      $fclose(bin_file);

      open_read(bin_file);
      for (int i = 1; i <= c_READ_WORDS; i++) begin
        colibri_binaryio::binword#(c_WORD_W)::read(bin_file, read_stream, empty);

        if (i < c_READ_WORDS) begin
          if (empty != 0)
            $fatal(1, "test_incomplete g_READ_BYTES=%0d word %0d: Non-zero empty bytes before EoF is reached",
                   g_READ_BYTES, i);
          src_hi   = c_VEC_W - 1 - (8 * (i - 1) * g_READ_BYTES);
          expected = test_vec[src_hi -: c_WORD_W];
        end else begin
          if (empty != int'(c_LAST_EMPTY))
            $fatal(1, "test_incomplete g_READ_BYTES=%0d: Incorrect number of empty bytes reported at EoF: Expected: %0d Received: %0d",
                   g_READ_BYTES, c_LAST_EMPTY, empty);
          // VHDL: v_expected(left downto 8*empty) gets the remaining low bits;
          // v_expected(8*empty-1 downto 0) is zero.
          expected = '0;
          expected[c_WORD_W - 1 -: c_TAIL_BITS] = test_vec[c_TAIL_HI -: c_TAIL_BITS];
        end

        if (read_stream != expected)
          $fatal(1, "test_incomplete g_READ_BYTES=%0d word %0d: Read values do not match the written ones: Expected: %h Received: %h",
                 g_READ_BYTES, i, expected, read_stream);
      end
      #1ns;
      $fclose(bin_file);

      $display("test_incomplete g_READ_BYTES=%0d: PASS", g_READ_BYTES);
      phase = g_READ_BYTES - 2;
    end
  end

  initial begin : proc_done
    wait (phase == 30);
    $display("binaryio_tb: PASS");
    $finish;
  end

  initial begin : proc_timeout
    #10us;
    $fatal(1, "binaryio_tb: timeout at phase %0d", phase);
  end

endmodule
