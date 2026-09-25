// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Stimulus for counter.psl. Modulo 10 matches the formal configuration.
module counter_tb;

  localparam int unsigned c_MODULO = 10;
  localparam int c_W = colibri_utils::log2ceil(int'(c_MODULO));

  logic             clk_i;
  logic             reset_i;
  logic             enable_i;
  logic [c_W-1:0]   value_o;
  logic             wraparound_o;
  logic [c_W-1:0]   expv;

  counter #(
    .g_MODULO(c_MODULO)
  ) dut (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .enable_i(enable_i),
    .value_o(value_o),
    .wraparound_o(wraparound_o)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    reset_i  = 1'b1;
    enable_i = 1'b0;
    expv     = '0;
    repeat (3) @(posedge clk_i);
    @(negedge clk_i);
    reset_i = 1'b0;
    @(posedge clk_i);
    if (value_o !== '0 || wraparound_o !== 1'b0)
      $fatal(1, "counter was not 0 after reset");

    repeat (3) begin
      @(posedge clk_i);
      if (value_o !== '0)
        $fatal(1, "counter moved while disabled");
    end

    @(negedge clk_i);
    enable_i = 1'b1;
    repeat (25) begin
      @(posedge clk_i);
      if (value_o !== expv)
        $fatal(1, "value %h expected %h", value_o, expv);
      if (expv == c_W'(c_MODULO - 1)) begin
        if (wraparound_o !== 1'b1)
          $fatal(1, "wraparound was not high at the last code");
        expv = '0;
      end else begin
        if (wraparound_o !== 1'b0)
          $fatal(1, "wraparound high at %h", expv);
        expv = expv + c_W'(1);
      end
    end

    @(negedge clk_i);
    enable_i = 1'b0;
    begin
      logic [c_W-1:0] held;
      @(posedge clk_i);
      held = value_o;
      repeat (4) begin
        @(posedge clk_i);
        if (value_o !== held)
          $fatal(1, "value changed while disabled");
      end
    end

    $display("PASS counter_tb");
    $finish;
  end

endmodule
