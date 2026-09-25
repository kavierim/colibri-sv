// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Some of the work was inspired by the PoC Library (https://github.com/VLSI-EDA/PoC)
//
// VHDL package `utils` in library `colibri` is SystemVerilog package `colibri_utils`.
// See CONVENTIONS.md for the call-site mapping.

`timescale 1ns/1ps

package colibri_utils;

  typedef enum logic [1:0] {
    AUTO    = 2'd0,
    QUARTUS = 2'd1,
    VIVADO  = 2'd2
  } compiler_t;

  // ceil(a / b). a is non-negative and b is positive, matching VHDL natural/positive.
  function automatic int div_ceil(input int a, input int b);
    return (a + (b - 1)) / b;
  endfunction

  // ceil(a / b) for positive time values. Result is a dimensionless natural.
  // Equivalent to VHDL `(a + (b - 1 fs)) / b` when both times are multiples of
  // the simulation precision (1 ps in this project).
  function automatic int div_ceil_time(input time a, input time b);
    time q;
    if (b == 0)
      return 0;
    q = a / b;
    if ((q * b) == a)
      return int'(q);
    return int'(q + 1);
  endfunction

  // ceil(a / b) with b a positive integer. Result stays a time.
  // Equivalent to the VHDL femtosecond formula for values that are multiples
  // of the simulation precision.
  function automatic time div_ceil_time_by_int(input time a, input int b);
    time q;
    if (b <= 0)
      return 0;
    q = a / time'(b);
    if ((q * time'(b)) == a)
      return q;
    return q + time'(1);
  endfunction

  // ceil(log2(arg)). log2ceil of 0 and of 1 is 0, matching the VHDL natural overload.
  function automatic int log2ceil(input int arg);
    int unsigned uarg;
    int unsigned v_tmp;
    int v_log;
    if (arg < 1)
      return 0;
    uarg  = int'(arg);
    v_tmp = 1;
    v_log = 0;
    for (int i = 0; i < 32; i++) begin
      if (uarg <= v_tmp)
        return v_log;
      v_tmp = v_tmp << 1;
      v_log = v_log + 1;
    end
    return v_log;
  endfunction

  // VHDL `(N-1 downto 0)` is a null range when N < 1. SV `[N-1:0]` is not.
  // Use this width for a downto-0 vector: values below 1 become 1.
  function automatic int downto_width(input int n);
    if (n < 1)
      return 1;
    return n;
  endfunction

  function automatic int greatest_common_div(input int n1, input int n2);
    int v_m1;
    int v_m2;
    int v_remainder;
    if (n1 > n2) begin
      v_m1 = n1;
      v_m2 = n2;
    end else begin
      v_m1 = n2;
      v_m2 = n1;
    end
    while (v_m2 != 0) begin
      v_remainder = v_m1 % v_m2;
      v_m1        = v_m2;
      v_m2        = v_remainder;
    end
    return v_m1;
  endfunction

  function automatic int least_common_mult(input int n1, input int n2);
    longint prod;
    prod = longint'(n1) * longint'(n2);
    prod = prod / longint'(greatest_common_div(n1, n2));
    return int'(prod);
  endfunction

  // Integer minimum/maximum. VHDL took these from ieee.math_real.
  // Equal inputs return the second argument.
  function automatic int minimum(input int a, input int b);
    if (a < b)
      return a;
    return b;
  endfunction

  function automatic int maximum(input int a, input int b);
    if (a > b)
      return a;
    return b;
  endfunction

  function automatic int if_sel(input bit condition, input int pos_case, input int neg_case);
    if (condition)
      return pos_case;
    return neg_case;
  endfunction

  // Synthesis translate-off regions match the VHDL compiler probes.
  // Under Verilator both functions return 0, so get_compiler returns AUTO.
  // Report strings from the VHDL are omitted so these stay constant functions.
  function automatic bit compiler_is_quartus();
    bit v_ret;
    v_ret = 1'b1;
    // altera translate_off
    v_ret = 1'b0;
    // altera translate_on
    return v_ret;
  endfunction

  function automatic bit compiler_is_vivado();
    bit v_ret;
    v_ret = 1'b1;
    // xilinx translate_off
    v_ret = 1'b0;
    // xilinx translate_on
    return v_ret;
  endfunction

  function automatic compiler_t get_compiler();
    if (compiler_is_quartus())
      return QUARTUS;
    else if (compiler_is_vivado())
      return VIVADO;
    else
      return AUTO;
  endfunction

  // Unsigned vector math. W is the VHDL `unsigned` width.
  // log2ceil's `bits` argument is unused, matching the VHDL body.
  class uval #(parameter int W_REQ = 1);
    localparam int W = (W_REQ < 1) ? 1 : W_REQ;

    static function automatic logic [W-1:0] div_ceil(input logic [W-1:0] a, input int b);
      logic [W:0] sum;
      sum = {1'b0, a} + (W + 1)'(b - 1);
      sum = sum / (W + 1)'(b);
      return sum[W-1:0];
    endfunction

    static function automatic logic [W-1:0] log2ceil(input logic [W-1:0] arg, input int bits);
      logic [W-1:0] v_tmp;
      logic [W-1:0] v_log;
      int scratch;
      scratch = bits;
      scratch = scratch;
      if (arg == W'(1))
        return '0;
      v_tmp    = '0;
      v_tmp[0] = 1'b1;
      v_log    = '0;
      for (int i = 0; i < W; i++) begin
        if (arg <= v_tmp)
          return v_log;
        v_tmp = v_tmp << 1;
        v_log = v_log + W'(1);
      end
      return v_log;
    endfunction
  endclass

  // Byte masks. SIZE is the VHDL `size` argument (a byte count).
  // The result is SIZE*8 bits, index 0 at the LSB.
  class byte_mask #(parameter int SIZE = 1);
    localparam int BITS = SIZE * 8;

    static function automatic logic [BITS-1:0] mask_bytes_left(input int pos);
      logic [BITS-1:0] v_ret;
      for (int i = 0; i < SIZE; i++) begin
        if (i < pos)
          v_ret[(BITS - 1) - (i * 8) -: 8] = '1;
        else
          v_ret[(BITS - 1) - (i * 8) -: 8] = '0;
      end
      return v_ret;
    endfunction

    static function automatic logic [BITS-1:0] mask_bytes_right(input int pos);
      return ~mask_bytes_left(pos);
    endfunction

    // Faithful to VHDL: pos_r is ignored, and the result is a mask ANDed with
    // its inverse, so the vector is 0 for every legal pos_l.
    // verilator lint_off UNUSEDSIGNAL
    static function automatic logic [BITS-1:0] mask_bytes(input int pos_l, input int pos_r);
      // pos_r is unused in the VHDL body.
      return mask_bytes_left(pos_l) & mask_bytes_right(pos_l);
    endfunction
    // verilator lint_on UNUSEDSIGNAL
  endclass

  // Packed-vector helpers. Index 0 is the LSB, matching VHDL `downto` vectors.
  class bits #(parameter int W_REQ = 1);
    localparam int W = (W_REQ < 1) ? 1 : W_REQ;

    static function automatic int count_ones(input logic [W-1:0] arg);
      return int'($countones(arg));
    endfunction

    static function automatic logic [W-1:0] invert_bit_order(input logic [W-1:0] word);
      logic [W-1:0] v_res;
      for (int i = 0; i < W; i++)
        v_res[i] = word[W - 1 - i];
      return v_res;
    endfunction

    static function automatic logic [W-1:0] swap_endianness(input logic [W-1:0] vec);
      logic [W-1:0] v_ret;
      int n_bytes;
      if ((W % 8) != 0)
        $error("Can't swap endianness if not byte-aligned.");
      n_bytes = W / 8;
      for (int i = 0; i < n_bytes; i++)
        v_ret[(W - 1) - (i * 8) -: 8] = vec[(i * 8) +: 8];
      return v_ret;
    endfunction

    static function automatic logic xorvec(input logic [W-1:0] vec);
      return ^vec;
    endfunction

    static function automatic logic andvec(input logic [W-1:0] vec);
      return &vec;
    endfunction

    // Even indexes are 1. VHDL indexed the integer through a log2ceil-wide
    // unsigned; a length of 1 made that unsigned a null range. Bit 0 of the
    // index is the same test for every positive length.
    static function automatic logic [W-1:0] gen_even();
      logic [W-1:0] v_ret;
      for (int i = 0; i < W; i++)
        v_ret[i] = ~i[0];
      return v_ret;
    endfunction

    static function automatic logic [W-1:0] gen_odd();
      logic [W-1:0] v_ret;
      for (int i = 0; i < W; i++)
        v_ret[i] = i[0];
      return v_ret;
    endfunction

    static function automatic logic [W-1:0] if_sel(
      input bit condition,
      input logic [W-1:0] pos_case,
      input logic [W-1:0] neg_case
    );
      if (condition)
        return pos_case;
      return neg_case;
    endfunction
  endclass

  // Byte slices of a downto vector. W is the vector width in bits and must
  // be a multiple of 8. Natural overloads from utils.vhdl.
  class byteslice #(parameter int W_REQ = 8);
    localparam int W = (W_REQ < 8) ? 8 : W_REQ;

    static function automatic logic [W-1:0] slice_bytes_left(input logic [W-1:0] vec, input int pos);
      if ((W % 8) != 0)
        $error("Can't slice if not byte-aligned.");
      return vec & byte_mask#(W / 8)::mask_bytes_left(pos);
    endfunction

    static function automatic logic [W-1:0] slice_bytes_right(input logic [W-1:0] vec, input int pos);
      logic [W-1:0] v_ret;
      if ((W % 8) != 0)
        $error("Can't slice if not byte-aligned.");
      v_ret = vec & byte_mask#(W / 8)::mask_bytes_left(pos);
      v_ret = v_ret << (W - (pos * 8));
      return v_ret;
    endfunction

    static function automatic logic [W-1:0] slice_bytes(
      input logic [W-1:0] vec,
      input int pos_l,
      input int pos_r
    );
      logic [W-1:0] v_ret;
      if ((W % 8) != 0)
        $error("Can't slice if not byte-aligned.");
      v_ret = vec & byte_mask#(W / 8)::mask_bytes_left(pos_r);
      v_ret = v_ret << (pos_l * 8);
      return v_ret;
    endfunction
  endclass

  // VHDL unsigned slice_bytes passes vec'length (a bit count) as the byte
  // count, so the mask is wider than vec. No in-tree callers. Kept separate
  // so specialising byteslice does not build that wide mask.
  class byteslice_u #(parameter int W_REQ = 8);
    localparam int W = (W_REQ < 1) ? 1 : W_REQ;

    static function automatic logic [W-1:0] slice_bytes(
      input logic [W-1:0] vec,
      input int pos_l,
      input int pos_r
    );
      logic [W-1:0] v_ret;
      logic [W*8-1:0] wide_mask;
      if ((W % 8) != 0)
        $error("Can't slice if not byte-aligned.");
      wide_mask = byte_mask#(W)::mask_bytes_left(pos_r);
      v_ret = vec & wide_mask[W-1:0];
      v_ret = v_ret << (pos_l * 8);
      return v_ret;
    endfunction
  endclass

endpackage

// VHDL `y <= x when registered(clk, g_REGISTER_OUT)`.
// A function cannot return a clock edge. Expand each use with a unique label.
`define COLIBRI_WHEN_REGISTERED(label, clk, is_reg, dst, src) \
  if ((is_reg) != 1'b0) begin : gen_reg_``label \
    always_ff @(posedge clk) dst <= (src); \
  end else begin : gen_comb_``label \
    assign dst = (src); \
  end
