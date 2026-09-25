// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Greater-or-equal comparator. sim/common/comparator_tb.vhdl:
// width 12, g_IS_EQUAL, ten hits of GT, LT, equal, and disabled.
module comparator_tb;

  localparam int  c_W   = 12;
  localparam time c_CLK = 5ns;

  logic             clk;
  logic             enable;
  logic [c_W-1:0]   a_i;
  logic [c_W-1:0]   b_i;
  logic             trigger;

  comparator #(
    .g_DATA_WIDTH(c_W),
    .g_IS_EQUAL(1'b1)
  ) dut (
    .clk_i(clk),
    .enable_i(enable),
    .a_i(a_i),
    .b_i(b_i),
    .a_gt_b_o(trigger)
  );

  initial begin
    clk = 1'b1;
    forever begin
      #(c_CLK / 2) clk = 1'b0;
      #(c_CLK / 2) clk = 1'b1;
    end
  end

  initial begin
    enable = 1'b0;
    a_i    = '0;
    b_i    = '0;
    repeat (10) @(posedge clk);

    for (int k = 0; k < 10; k++) begin
      int unsigned a;
      int unsigned b;

      a = $urandom_range(1, (1 << c_W) - 1);
      b = $urandom_range(0, a - 1);
      drive(1'b1, a, b);
      @(posedge clk);
      #1;
      if (trigger !== 1'b1)
        $fatal(1, "GT trigger not fired a=%0d b=%0d", a, b);
      enable = 1'b0;
      @(posedge clk);

      a = $urandom_range(0, (1 << c_W) - 2);
      b = $urandom_range(a + 1, (1 << c_W) - 1);
      drive(1'b1, a, b);
      @(posedge clk);
      #1;
      if (trigger !== 1'b0)
        $fatal(1, "Fired when LT a=%0d b=%0d", a, b);
      enable = 1'b0;
      @(posedge clk);

      a = $urandom_range(0, (1 << c_W) - 1);
      drive(1'b1, a, a);
      @(posedge clk);
      #1;
      if (trigger !== 1'b1)
        $fatal(1, "Equal trigger not fired a=%0d", a);
      enable = 1'b0;
      @(posedge clk);

      a = $urandom_range(1, (1 << c_W) - 1);
      b = $urandom_range(0, a - 1);
      drive(1'b0, a, b);
      @(posedge clk);
      if (trigger !== 1'b0)
        $fatal(1, "Fired when disabled (before update)");
      #1;
      if (trigger !== 1'b0)
        $fatal(1, "Fired when disabled a=%0d b=%0d", a, b);
      enable = 1'b0;
      @(posedge clk);
    end

    $display("PASS comparator_tb");
    $finish;
  end

  task automatic drive(input logic en, input int unsigned a, input int unsigned b);
    enable = en;
    a_i    = c_W'(a);
    b_i    = c_W'(b);
  endtask

endmodule
