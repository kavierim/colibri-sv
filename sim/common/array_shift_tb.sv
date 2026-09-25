// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Left and right shifts of an slv array. sim/common/array_shift_tb.vhdl
// defaults: 16 elements of 16 bits. Both VUnit cases run here.
module array_shift_tb;

  localparam int c_ELEM = 16;
  localparam int c_LEN  = 16;

  logic [c_ELEM-1:0] test_array [0:c_LEN-1];
  logic [c_ELEM-1:0] shifted [0:c_LEN-1];

  initial begin
    for (int i = 0; i < c_LEN; i++)
      test_array[i] = c_ELEM'(i);

    for (int i = 0; i < c_LEN; i++) begin
      shifted = colibri_types::slv_arr#(c_LEN, c_ELEM)::shift_left_arr(test_array, i);
      for (int j = 0; j <= (c_LEN - 1 - i); j++) begin
        if (shifted[j] !== test_array[j + i])
          $fatal(1, "left shift by %0d at %0d: got %h expected %h",
                 i, j, shifted[j], test_array[j + i]);
      end
      for (int j = c_LEN - i; j < c_LEN; j++) begin
        if (shifted[j] !== '0)
          $fatal(1, "left shift by %0d left a non-zero at %0d (%h)", i, j, shifted[j]);
      end
    end

    for (int i = 0; i < c_LEN; i++) begin
      shifted = colibri_types::slv_arr#(c_LEN, c_ELEM)::shift_right_arr(test_array, i);
      for (int j = 0; j < i; j++) begin
        if (shifted[j] !== '0)
          $fatal(1, "right shift by %0d left a non-zero at %0d (%h)", i, j, shifted[j]);
      end
      for (int j = i; j < c_LEN; j++) begin
        if (shifted[j] !== test_array[j - i])
          $fatal(1, "right shift by %0d at %0d: got %h expected %h",
                 i, j, shifted[j], test_array[j - i]);
      end
    end

    $display("PASS array_shift_tb");
    $finish;
  end

endmodule
