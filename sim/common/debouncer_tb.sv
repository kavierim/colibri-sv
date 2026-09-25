// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Stimulus for debouncer.psl. Generics match debouncer_fv.vhdl.
module debouncer_tb;

  localparam time c_CLK = 10ns;

  logic       clk_i;
  logic       reset_i;
  logic [3:0] data_i;
  logic [3:0] data_o;

  // verilator lint_off REALCVT
  debouncer #(
    .g_RESET_VAL(4'b0000),
    .g_DEBOUNCE_TIME(100ns),
    .g_CLOCK_PERIOD(10ns)
  ) dut (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .data_i(data_i),
    .data_o(data_o)
  );
  // verilator lint_on REALCVT

  initial begin
    clk_i = 1'b0;
    forever #(c_CLK / 2) clk_i = ~clk_i;
  end

  initial begin
    reset_i = 1'b1;
    data_i  = 4'h0;
    repeat (4) @(posedge clk_i);
    #1;
    if (data_o !== 4'h0)
      $fatal(1, "reset value was not 0");
    @(negedge clk_i);
    reset_i = 1'b0;

    // Eleven samples after reset are inside the PSL unstable bound.
    @(negedge clk_i);
    data_i = 4'h7;
    repeat (11) @(posedge clk_i);
    @(negedge clk_i);
    data_i = 4'h8;
    @(posedge clk_i);
    #1;
    if (data_o !== 4'h0)
      $fatal(1, "11-cycle input was accepted: %h", data_o);

    @(negedge clk_i);
    data_i = 4'hA;
    repeat (20) @(posedge clk_i);
    #1;
    if (data_o !== 4'hA)
      $fatal(1, "stable input 0xA was not accepted, got %h", data_o);

    // One new value per clock, so data_i and data_reg differ at every edge.
    // A counter that is about to wrap cannot accept the glitch. Each value
    // is stable for a single sample: the 1-cycle PSL bound.
    repeat (16) begin
      @(negedge clk_i);
      data_i = data_i + 4'h1;
    end
    @(posedge clk_i);
    #1;
    if (data_o !== 4'hA)
      $fatal(1, "output followed an unstable input: %h", data_o);

    @(negedge clk_i);
    data_i = 4'h5;
    repeat (20) @(posedge clk_i);
    #1;
    if (data_o !== 4'h5)
      $fatal(1, "stable input 0x5 was not accepted, got %h", data_o);

    $display("PASS debouncer_tb");
    $finish;
  end

endmodule
