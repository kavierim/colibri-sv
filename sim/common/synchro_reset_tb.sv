// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Reset synchronizer. sim/common/synchro_reset_tb.vhdl defaults:
// active-high in and out, duration 1, 10 ns clock.
module synchro_reset_tb;

  localparam logic g_IN_POLARITY  = 1'b1;
  localparam logic g_OUT_POLARITY = 1'b1;
  localparam int   g_DURATION     = 1;
  localparam time  c_CLK          = 10ns;

  logic clk_i;
  logic reset_i;
  logic reset_o;

  synchro_reset #(
    .g_IN_POLARITY(g_IN_POLARITY),
    .g_OUT_POLARITY(g_OUT_POLARITY),
    .g_DURATION(g_DURATION)
  ) u_synchro_reset (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .reset_o(reset_o)
  );

  initial begin
    clk_i = 1'b1;
    forever begin
      #(c_CLK / 2) clk_i = 1'b0;
      #(c_CLK / 2) clk_i = 1'b1;
    end
  end

  initial begin
    reset_i = ~g_IN_POLARITY;
    @(posedge clk_i);
    if (reset_o !== ~g_OUT_POLARITY)
      $fatal(1, "reset output was not initialized");
    repeat (3) @(posedge clk_i);

    #(c_CLK / 4);
    reset_i = g_IN_POLARITY;
    #(c_CLK / 4);
    if (reset_o !== g_OUT_POLARITY)
      $fatal(1, "reset was not asserted asynchronously");
    #(c_CLK / 4);
    reset_i = ~g_IN_POLARITY;

    @(posedge clk_i);
    if (g_DURATION > 1)
      repeat (g_DURATION - 1) @(posedge clk_i);
    if (reset_o !== g_OUT_POLARITY)
      $fatal(1, "reset was not kept for g_DURATION clocks");
    @(posedge clk_i);
    #(c_CLK / 4);
    if (reset_o !== ~g_OUT_POLARITY)
      $fatal(1, "reset was not deasserted after g_DURATION clocks");

    $display("PASS synchro_reset_tb");
    $finish;
  end

endmodule
