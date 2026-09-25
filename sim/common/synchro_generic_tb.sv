// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Generic synchronizer. Same scenario as synchro_tb, on synchro_generic.
module synchro_generic_tb;

  localparam int  c_W      = 32;
  localparam int  c_STAGES = 2;
  localparam time c_CLK    = 10ns;
  localparam logic [c_W-1:0] c_INIT = '1;

  logic             clk_i;
  logic             reset_i;
  logic [c_W-1:0]   data_i;
  logic [c_W-1:0]   data_o;

  synchro_generic #(
    .data_t(logic [c_W-1:0]),
    .g_INIT_VALUE(c_INIT),
    .g_NUM_STAGES(c_STAGES)
  ) u_synchro (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .data_i(data_i),
    .data_o(data_o)
  );

  initial begin
    clk_i = 1'b1;
    forever begin
      #(c_CLK / 2) clk_i = 1'b0;
      #(c_CLK / 2) clk_i = 1'b1;
    end
  end

  initial begin
    reset_i = 1'b0;
    data_i  = ~c_INIT;
    @(posedge clk_i);
    if (data_o !== c_INIT)
      $fatal(1, "output was not initialized: %h", data_o);

    repeat (c_STAGES) @(posedge clk_i);
    if (data_o !== data_i)
      $fatal(1, "input did not reach the output: got %h exp %h", data_o, data_i);

    #(c_CLK / 3);
    data_i = 32'd33;
    repeat (c_STAGES) @(posedge clk_i);
    if (data_o === data_i)
      $fatal(1, "output transitioned before all stages");
    @(posedge clk_i);
    if (data_o !== data_i)
      $fatal(1, "input did not reach the output after the extra stage");

    @(posedge clk_i);
    @(negedge clk_i);
    reset_i = 1'b1;
    repeat (2) @(posedge clk_i);
    if (data_o !== c_INIT)
      $fatal(1, "reset did not re-initialize the output: %h", data_o);
    @(negedge clk_i);
    reset_i = 1'b0;
    repeat (c_STAGES + 1) @(posedge clk_i);
    if (data_o !== data_i)
      $fatal(1, "input did not reach the output after reset");

    $display("PASS synchro_generic_tb");
    $finish;
  end

endmodule
