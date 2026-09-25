// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Shared helpers for the packet testbenches. Random draws are bounded
// $urandom_range calls. Seed once, then draw; $urandom(seed) reseeds.

`timescale 1ns/1ps

package packet_tb_pkg;

  function automatic void seed_rand(input int unsigned seed);
    void'($urandom(seed));
  endfunction

  function automatic int unsigned urand(input int unsigned lo, input int unsigned hi);
    if (hi <= lo)
      return lo;
    return lo + $urandom_range(hi - lo);
  endfunction

  function automatic logic [7:0] urand8();
    return 8'($urandom_range(255, 0));
  endfunction

  // Big-endian symbol insert/extract. Variable part-selects on the left-hand
  // side are dropped by Verilator 5.020, so the word is built with shifts.
  function automatic logic [255:0] be_put(
    input logic [255:0] word,
    input logic [31:0]  sym,
    input int           index,
    input int           sym_w,
    input int           nsyms
  );
    int            sh;
    logic [255:0] mask_w;
    logic [255:0] sym_w256;
    sh       = sym_w * (nsyms - 1 - index);
    mask_w   = (sym_w >= 32) ? {256{1'b1}} : (256'h1 << sym_w) - 1;
    sym_w256 = 256'(sym) & mask_w;
    return (word & ~(mask_w << sh)) | (sym_w256 << sh);
  endfunction

  function automatic logic [31:0] be_get(
    input logic [255:0] word,
    input int           index,
    input int           sym_w,
    input int           nsyms
  );
    int          sh;
    logic [31:0] mask;
    sh   = sym_w * (nsyms - 1 - index);
    mask = (sym_w >= 32) ? 32'hffff_ffff : (32'h1 << sym_w) - 1;
    return 32'(word >> sh) & mask;
  endfunction

endpackage
