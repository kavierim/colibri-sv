// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
// Work inspired by VHDL-extras (http://github.com/kevinpt/vhdl-extras)

`timescale 1ns/1ps

// VHDL package `binaryio`: procedures on a file of byte.
//
// `binary_file_t` is an `$fopen` descriptor, not a VHDL file object. Open it
// with `"rb"` or `"wb"` and close it with `$fclose` (VHDL `file_open` /
// `file_close` stay at the call site). `std_logic_vector` and `unsigned` are
// both `logic [W-1:0]`, so those overloads are one specialization.
// Lint rejects a second task named `read`. The class is `binword` so the
// argument can stay `word`:
//   binword#(W)::read(bin_file, word, empty) - incomplete read; `empty` is the
//     number of unread bytes at the LSB (VHDL `read` with `empty`)
//   binword#(W)::read_full(bin_file, word)   - VHDL `read` without `empty`;
//     `$error` if `empty` is not 0 (severity error, word still updated)
//   binword#(W)::write(bin_file, word)
// `write` calls `$fflush` so the word is in the file when the task returns.
// `W` is `word'length` and must be >= 1.
// A `$fread` that does not return 1 is end of file, including a bad
// descriptor. `$feof` is not used: it becomes true only after
// that short read, unlike VHDL `endfile` before the read. Each file byte is
// one `$fread` or `$fwrite(..., "%c", ...)`. One wide `$fread` does not leave
// a short word's missing LSB bytes the way this loop does.
// The first file byte is the most significant byte of the `div_ceil(W, 8)`
// byte aligned word. Narrowing keeps the low `W` bits, matching `resize`.

package colibri_binaryio;

  typedef int binary_file_t;

  class binword #(parameter int W = 8);
    localparam int c_N_BYTES   = colibri_utils::div_ceil(W, 8);
    localparam int c_ALIGNED_W = c_N_BYTES * 8;

    // Incomplete read allowed. `empty` is the number of missing LSB bytes.
    static task automatic read(
      input binary_file_t bin_file,
      output logic [W-1:0] word,
      output int unsigned empty
    );
      logic [c_ALIGNED_W-1:0] aligned;
      logic [7:0] cur_byte;
      int nread;

      // MSB first, same bytes as VHDL left-(i*8) downto length-(i+1)*8.
      // A variable part-select in a static task does not compile here, so
      // each new byte is shifted in at the LSB and a short read shifts that
      // run up to the top of the aligned word. The low 8*empty bits stay 0.
      empty   = 0;
      aligned = '0;
      for (int i = 0; i < c_N_BYTES; i++) begin
        nread = $fread(cur_byte, bin_file);
        if (nread == 1) begin
          aligned = (aligned << 8) | c_ALIGNED_W'(cur_byte);
        end else begin
          empty   = c_N_BYTES - i;
          aligned = aligned << (8 * empty);
          break;
        end
      end
      word = aligned[W-1:0];
    endtask

    // VHDL `read` without `empty`: severity error when the word is short.
    static task automatic read_full(
      input binary_file_t bin_file,
      output logic [W-1:0] word
    );
      int unsigned empty;
      read(bin_file, word, empty);
      if (empty != 0)
        $error("End of file reached before read completed");
    endtask

    static task automatic write(
      input binary_file_t bin_file,
      input logic [W-1:0] word
    );
      logic [c_ALIGNED_W-1:0] aligned;
      logic [7:0] cur_byte;

      // Top byte is the next file byte. `c_ALIGNED_W-1` is constant, so this
      // is not a variable part-select.
      aligned = c_ALIGNED_W'(word);
      for (int i = 0; i < c_N_BYTES; i++) begin
        cur_byte = aligned[c_ALIGNED_W-1 -: 8];
        $fwrite(bin_file, "%c", cur_byte);
        aligned = aligned << 8;
      end
      $fflush(bin_file);
    endtask
  endclass

endpackage
