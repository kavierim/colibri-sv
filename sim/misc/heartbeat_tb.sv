// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-check for heartbeat. Half of g_BEAT_PERIOD toggles heartbeat_o.

`timescale 1ns/1ps

module heartbeat_tb;

  // verilator lint_off REALCVT
  localparam time c_CLK_PERIOD  = 10ns;
  localparam time c_BEAT_PERIOD = 100ns;
  // verilator lint_on REALCVT

  logic clk_i       = 1'b1;
  logic reset_i     = 1'b1;
  logic heartbeat_o;

  heartbeat #(
    .g_BEAT_PERIOD(c_BEAT_PERIOD),
    .g_CLK_PERIOD (c_CLK_PERIOD)
  ) dut (
    .clk_i      (clk_i),
    .reset_i    (reset_i),
    .heartbeat_o(heartbeat_o)
  );

  always #(c_CLK_PERIOD / 2) clk_i = ~clk_i;

  initial begin : proc_vunit
    #(c_BEAT_PERIOD);
    @(negedge clk_i);
    reset_i = 1'b0;
  // Count rising edges after reset. The beat is 5 clocks, so each check
  // lands on the cycle after the toggle.
  @(posedge clk_i);
  if (heartbeat_o !== 1'b0)
    $fatal(1, "heartbeat was not 0 after reset");

  for (int i = 0; i <= 100; i++) begin
    repeat (5) @(posedge clk_i);
    if (heartbeat_o !== 1'b1)
      $fatal(1, "heartbeat was not 1 after half period at i=%0d t=%0t", i, $time);
    repeat (5) @(posedge clk_i);
    if (heartbeat_o !== 1'b0)
      $fatal(1, "heartbeat was not 0 after half period at i=%0d t=%0t", i, $time);
  end

    $display("PASS heartbeat_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #1ms;
    $fatal(1, "heartbeat_tb watchdog");
  end

endmodule
