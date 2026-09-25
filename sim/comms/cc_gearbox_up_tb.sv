// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from cc_gearbox_up_tb.vhdl: 8-bit to 10-bit, 5 ns write clock, 8 ns read clock.

`timescale 1ns/1ps

module cc_gearbox_up_tb;

  localparam int c_IN = 8;
  localparam int c_OUT = 10;
  localparam int c_BUF = 4;
  localparam int c_TEST = colibri_utils::least_common_mult(c_IN, c_OUT) * c_BUF * 5;

  logic                snk_clk = 1'b1;
  logic                src_clk = 1'b1;
  logic                reset = 1'b1;
  logic [c_IN-1:0]     snk_data = '0;
  logic                snk_valid = 1'b0;
  logic                snk_ready;
  logic [c_OUT-1:0]    src_data;
  logic                src_valid;
  logic                src_ready = 1'b0;
  logic [c_TEST-1:0]   test_vec;
  int                  rd_bits = 0;
  int                  src_stall = 0;

  always #2.5 snk_clk = ~snk_clk;
  always #4 src_clk = ~src_clk;

  cc_gearbox #(
    .g_INPUT_WIDTH(c_IN),
    .g_OUTPUT_WIDTH(c_OUT),
    .g_BUFFER_WORDS(c_BUF)
  ) dut (
    .snk_clk_i(snk_clk),
    .snk_reset_i(reset),
    .src_clk_i(src_clk),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  always @(posedge src_clk) begin
    if (reset) begin
      src_ready <= 1'b0;
      src_stall <= 0;
    end else begin
      if (src_valid && src_ready && (rd_bits < c_TEST)) begin
        if (src_data != test_vec[c_TEST-1-rd_bits -: c_OUT])
          $fatal(1, "cc_gearbox_up: mismatch at bit %0d got %h exp %h",
                 rd_bits, src_data, test_vec[c_TEST-1-rd_bits -: c_OUT]);
        rd_bits <= rd_bits + c_OUT;
      end
      if (src_stall > 0) begin
        src_ready <= 1'b0;
        src_stall <= src_stall - 1;
      end else begin
        src_ready <= 1'b1;
        if (src_valid && src_ready && ($urandom_range(0, 1) == 1))
          src_stall <= $urandom_range(1, 8);
      end
    end
  end

  task automatic send_word(input logic [c_IN-1:0] word);
    int guard;
    @(negedge snk_clk);
    if ($urandom_range(0, 1) == 1)
      repeat ($urandom_range(1, 8)) @(posedge snk_clk);
    @(negedge snk_clk);
    snk_data  = word;
    snk_valid = 1'b1;
    guard = 0;
    @(posedge snk_clk);
    while (!(snk_valid && snk_ready)) begin
      @(posedge snk_clk);
      guard++;
      if (guard > 1000000)
        $fatal(1, "cc_gearbox_up: sink timeout");
    end
    @(negedge snk_clk);
    snk_valid = 1'b0;
  endtask

  initial begin
    for (int i = 0; i < c_TEST; i++)
      test_vec[c_TEST-1-i] = 1'($urandom_range(0, 1));
    repeat (3) @(posedge snk_clk);
    @(negedge snk_clk);
    reset = 1'b0;
    for (int p = 0; p < c_TEST; p += c_IN)
      send_word(test_vec[c_TEST-1-p -: c_IN]);
    begin
      int guard;
      guard = 0;
      while (rd_bits < c_TEST) begin
        @(posedge src_clk);
        guard++;
        if (guard > 2000000)
          $fatal(1, "cc_gearbox_up: source timeout at %0d", rd_bits);
      end
    end
    $display("PASS cc_gearbox_up_tb");
    $finish;
  end

  initial begin
    #5ms;
    $fatal(1, "timeout cc_gearbox_up_tb");
  end

endmodule
