// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Popcount wrapper from utils.psl / utils_fv.vhdl.
module utils_tb;

  logic        clk_i;
  logic        reset_i;
  logic [63:0] count_ones_i;
  int          count_ones_o;
  int          expect_n;

  utils_fv dut (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .count_ones_i(count_ones_i),
    .count_ones_o(count_ones_o)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  function automatic int popcount(input logic [63:0] value);
    int n;
    n = 0;
    for (int i = 0; i < 64; i++)
      if (value[i])
        n = n + 1;
    return n;
  endfunction

  initial begin
    reset_i      = 1'b1;
    count_ones_i = '0;
    repeat (2) @(posedge clk_i);
    @(negedge clk_i);
    reset_i = 1'b0;

    check_vec(64'h0);
    check_vec(64'h1);
    check_vec(64'h8000_0000_0000_0000);
    check_vec(64'hFFFF_FFFF_FFFF_FFFF);
    check_vec(64'h0123_4567_89AB_CDEF);
    repeat (32) begin
      check_vec({$urandom, $urandom});
    end

    $display("PASS utils_tb");
    $finish;
  end

  task automatic check_vec(input logic [63:0] value);
    @(negedge clk_i);
    count_ones_i = value;
    expect_n = popcount(value);
    @(posedge clk_i);
    #1;
    if (count_ones_o !== expect_n)
      $fatal(1, "count_ones(%h) = %0d, expected %0d", value, count_ones_o, expect_n);
  endtask

endmodule
