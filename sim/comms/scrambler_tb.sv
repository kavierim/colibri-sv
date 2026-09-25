// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from scrambler_tb.vhdl: a constant 64-bit word round-trips the default 10GBASE pair.

`timescale 1ns/1ps

module scrambler_tb;

  localparam int c_DATA_WIDTH = 64;
  localparam logic [c_DATA_WIDTH-1:0] c_WORD = 64'hA0750F3BF76980F6;

  logic                      clk = 1'b1;
  logic                      reset = 1'b1;
  logic [c_DATA_WIDTH-1:0]   snk_data = '0;
  logic [c_DATA_WIDTH-1:0]   src_data;
  logic [c_DATA_WIDTH-1:0]   scrambled_data;
  logic                      valid_sig;
  logic                      src_valid;
  logic                      ready_sig;

  always #5 clk = ~clk;

  scrambler #(
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) scrambler_inst (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_valid_i(1'b1),
    .snk_ready_o(),
    .src_data_o(scrambled_data),
    .src_valid_o(valid_sig),
    .src_ready_i(ready_sig)
  );

  descrambler #(
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) descrambler_inst (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(scrambled_data),
    .snk_valid_i(valid_sig),
    .snk_ready_o(ready_sig),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(1'b1)
  );

  always @(posedge clk) begin
    if (!reset && src_valid && (src_data != c_WORD))
      $fatal(1, "scrambler_tb: c_word mismatch got %h", src_data);
  end

  initial begin
    @(posedge clk);
    reset    = 1'b0;
    snk_data = c_WORD;
    repeat (40) @(posedge clk);
    if (!src_valid)
      $fatal(1, "scrambler_tb: descrambler never produced a word");
    $display("PASS scrambler_tb");
    $finish;
  end

  initial begin
    #10us;
    $fatal(1, "timeout scrambler_tb");
  end

endmodule
