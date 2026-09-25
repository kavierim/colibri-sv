// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from cc_gearbox_up_thr_tb.vhdl: no stalls, and src_ready stays high
// for the whole transfer (check_stable on src_ready).

`timescale 1ns/1ps

module cc_gearbox_up_thr_tb;

  localparam int c_IN = 8;
  localparam int c_OUT = 10;
  localparam int c_BUF = 12;
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
  logic                window = 1'b0;

  always #4 snk_clk = ~snk_clk;
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
    end else begin
      src_ready <= 1'b1;
      if (window && !src_ready)
        $fatal(1, "cc_gearbox_up_thr: src_ready was not stable");
      if (src_valid && src_ready && (rd_bits < c_TEST)) begin
        if (src_data != test_vec[c_TEST-1-rd_bits -: c_OUT])
          $fatal(1, "cc_gearbox_up_thr: mismatch at bit %0d got %h exp %h",
                 rd_bits, src_data, test_vec[c_TEST-1-rd_bits -: c_OUT]);
        rd_bits <= rd_bits + c_OUT;
        window  <= 1'b1;
      end
    end
  end

  task automatic send_word(input logic [c_IN-1:0] word);
    int guard;
    @(negedge snk_clk);
    snk_data  = word;
    snk_valid = 1'b1;
    guard = 0;
    @(posedge snk_clk);
    while (!(snk_valid && snk_ready)) begin
      @(posedge snk_clk);
      guard++;
      if (guard > 1000000)
        $fatal(1, "cc_gearbox_up_thr: sink timeout");
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
          $fatal(1, "cc_gearbox_up_thr: source timeout at %0d", rd_bits);
      end
    end
    window = 1'b0;
    $display("PASS cc_gearbox_up_thr_tb");
    $finish;
  end

  initial begin
    #5ms;
    $fatal(1, "timeout cc_gearbox_up_thr_tb");
  end

endmodule
