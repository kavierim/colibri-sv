// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Some of the work was inspired by the PoC Library (https://github.com/VLSI-EDA/PoC)
//
// VHDL package `encoders` in library `colibri` is SystemVerilog package `colibri_encoders`.

`timescale 1ns/1ps

package colibri_encoders;

  import colibri_utils::*;

  function automatic logic [3:0] bin2bcd(input int arg);
    if (arg >= 10)
      $warning("binary overflow bcd");
    return 4'(arg);
  endfunction

  // VHDL asserts failure unless the vector is exactly 4 bits. The signature is that width.
  function automatic logic [3:0] bcd2bin(input logic [3:0] arg);
    return arg;
  endfunction

  class enc #(parameter int W_REQ = 1);
    localparam int W = (W_REQ < 1) ? 1 : W_REQ;

    static function automatic logic [W-1:0] bin2gray(input logic [W-1:0] arg);
      if (W <= 1)
        return arg;
      return {1'b0, arg[W-1:1]} ^ arg;
    endfunction

    static function automatic logic [W-1:0] gray2bin(input logic [W-1:0] arg);
      logic [W-1:0] v_ret;
      v_ret = arg;
      for (int i = W - 2; i >= 0; i--)
        v_ret[i] = v_ret[i+1] ^ v_ret[i];
      return v_ret;
    endfunction

    // VHDL bin2gray(natural, max), with W = downto_width(log2ceil(max)).
    // verilator lint_off UNUSEDSIGNAL
    static function automatic logic [W-1:0] bin2gray_nat(input int arg);
      return bin2gray(W'(arg));
    endfunction
    // verilator lint_on UNUSEDSIGNAL

    static function automatic int gray2bin_nat(input logic [W-1:0] arg);
      return int'(gray2bin(arg));
    endfunction
  endclass

  // bin2onehot(unsigned) -> width 2**BIN_W. Keep BIN_W small (practical max 16).
  class onehot_enc #(parameter int BIN_W = 1);
    localparam int OH_W = 1 << BIN_W;

    static function automatic logic [OH_W-1:0] bin2onehot(input logic [BIN_W-1:0] arg);
      logic [OH_W-1:0] v_ret;
      v_ret = '0;
      for (int i = 0; i < OH_W; i++) begin
        if (i == int'(arg))
          v_ret[i] = 1'b1;
      end
      return v_ret;
    endfunction
  endclass

  // onehot2bin(std_logic_vector). The last '1' scanned from index 0 wins.
  // No '1' returns 0. VHDL left that result uninitialized ('U').
  class onehot_dec #(parameter int OH_W = 1);
    localparam int IDX_W = downto_width(log2ceil(OH_W));

    static function automatic logic [IDX_W-1:0] onehot2bin(input logic [OH_W-1:0] arg);
      logic [IDX_W-1:0] v_ret;
      v_ret = '0;
      for (int i = 0; i < OH_W; i++) begin
        if (arg[i] == 1'b1)
          v_ret = IDX_W'(i);
      end
      return v_ret;
    endfunction
  endclass

  // bin2onehot / onehot2bin with an explicit state count `max`.
  class onehot_lim #(parameter int MAX = 1);
    localparam int IDX_W = downto_width(log2ceil(MAX));

    static function automatic logic [MAX-1:0] bin2onehot(input logic [IDX_W-1:0] arg);
      logic [MAX-1:0] v_ret;
      v_ret = '0;
      for (int i = 0; i < MAX; i++) begin
        if (i == int'(arg))
          v_ret[i] = 1'b1;
      end
      return v_ret;
    endfunction

    static function automatic logic [IDX_W-1:0] onehot2bin(input logic [MAX-1:0] arg);
      logic [IDX_W-1:0] v_ret;
      v_ret = '0;
      for (int i = 0; i < MAX; i++) begin
        if (arg[i] == 1'b1)
          v_ret = IDX_W'(i);
      end
      return v_ret;
    endfunction
  endclass

  // First '1' in a downto scan (MSB first). No '1' returns 0.
  class pri #(parameter int W = 1);
    localparam int IDX_W = downto_width(log2ceil(W));

    static function automatic logic [IDX_W-1:0] priority_encode(input logic [W-1:0] arg);
      for (int i = W - 1; i >= 0; i--) begin
        if (arg[i] == 1'b1)
          return IDX_W'(i);
      end
      return '0;
    endfunction
  endclass

endpackage
