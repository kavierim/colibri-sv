// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Stimulus for edge_detect.psl, both reset polarities.
module edge_detect_tb;

  logic clk_i;
  logic data0;
  logic data1;
  logic pulse0;
  logic pulse1;

  edge_detect #(
    .g_RESET_VAL(1'b0)
  ) dut0 (
    .clk_i(clk_i),
    .data_i(data0),
    .pulse_o(pulse0)
  );

  edge_detect #(
    .g_RESET_VAL(1'b1)
  ) dut1 (
    .clk_i(clk_i),
    .data_i(data1),
    .pulse_o(pulse1)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    data0 = 1'b0;
    data1 = 1'b1;
    repeat (4) @(posedge clk_i);

    check_edge(1'b0);
    check_edge(1'b1);

    repeat (30) begin
      @(negedge clk_i);
      if (($urandom % 2) == 0)
        data0 = ~data0;
      if (($urandom % 2) == 0)
        data1 = ~data1;
      @(posedge clk_i);
    end

    $display("PASS edge_detect_tb");
    $finish;
  end

  task automatic check_edge(input logic which);
    logic expect_pulse;
    @(negedge clk_i);
    if (which == 1'b0) begin
      data0 = 1'b1;
      expect_pulse = 1'b1;
    end else begin
      data1 = 1'b0;
      expect_pulse = 1'b0;
    end
    // The pulse is combinational and ends when data_reg catches the input.
    @(posedge clk_i);
    if (which == 1'b0) begin
      if (pulse0 !== expect_pulse)
        $fatal(1, "rising edge did not pulse");
    end else if (pulse1 !== expect_pulse) begin
      $fatal(1, "falling edge did not pulse for reset-high");
    end
    #1;
    if (which == 1'b0) begin
      if (pulse0 !== 1'b0)
        $fatal(1, "pulse stayed high after the registering clock");
    end else if (pulse1 !== 1'b1) begin
      $fatal(1, "pulse stayed low after the registering clock");
    end

    @(posedge clk_i);
    if (which == 1'b0) begin
      if (pulse0 !== 1'b0)
        $fatal(1, "stable high produced a pulse");
    end else if (pulse1 !== 1'b1) begin
      $fatal(1, "stable low produced a pulse for reset-high");
    end

    @(negedge clk_i);
    if (which == 1'b0)
      data0 = 1'b0;
    else
      data1 = 1'b1;
    @(posedge clk_i);
    #1;
    if (which == 1'b0) begin
      if (pulse0 !== 1'b0)
        $fatal(1, "return to reset produced a pulse");
    end else if (pulse1 !== 1'b1) begin
      $fatal(1, "return to reset-high produced a non-reset pulse");
    end
  endtask

endmodule
