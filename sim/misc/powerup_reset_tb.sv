// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-check for the power-up reset pulse and the external reset restart.

`timescale 1ns/1ps

module powerup_reset_tb;

  // verilator lint_off REALCVT
  localparam time c_CLK_PERIOD = 10ns;
  // verilator lint_on REALCVT
  localparam logic c_POLARITY  = 1'b1;
  localparam int   c_DURATION  = 10;

  logic clk_i       = 1'b1;
  logic reset_ext_i = 1'b0;
  logic reset_o;

  powerup_reset #(
    .g_POLARITY(c_POLARITY),
    .g_DURATION(c_DURATION)
  ) dut (
    .clk_i      (clk_i),
    .reset_ext_i(reset_ext_i),
    .reset_o    (reset_o)
  );

  always #(c_CLK_PERIOD / 2) clk_i = ~clk_i;

  initial begin : proc_vunit
    #1ps;
    if (reset_o !== c_POLARITY)
      $fatal(1, "reset output was not active at start");

    #(c_DURATION * c_CLK_PERIOD);
    @(posedge clk_i);
    #(c_CLK_PERIOD / 10);
    if (reset_o !== !c_POLARITY)
      $fatal(1, "reset output stayed active after the duration");

    #1us;
    @(posedge clk_i);

    reset_ext_i = 1'b1;
    #(c_CLK_PERIOD / 10);
    if (reset_o !== c_POLARITY)
      $fatal(1, "reset output did not follow external reset");

    #(3 * c_CLK_PERIOD);
    @(posedge clk_i);
    reset_ext_i = 1'b0;
    if (reset_o !== c_POLARITY)
      $fatal(1, "reset output dropped when external reset was released");

    #(c_DURATION * c_CLK_PERIOD);
    @(posedge clk_i);
    #(c_CLK_PERIOD / 10);
    if (reset_o !== !c_POLARITY)
      $fatal(1, "reset output stayed active after external reset");

    $display("PASS powerup_reset_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #1ms;
    $fatal(1, "powerup_reset_tb watchdog");
  end

endmodule
