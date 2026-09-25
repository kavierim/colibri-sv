// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from cc_gearbox_loopback_tb.vhdl. Same width sweep as the single-clock
// loopback. The middle clock period is 2/7 of the 5 ns port clock.

`timescale 1ns/1ps

module cc_gearbox_loop_case #(
  parameter int g_A_WIDTH = 16,
  parameter int g_B_WIDTH = 8,
  parameter int g_TEST_SIZE = 10
) (
  input  logic clk,
  input  logic gbx_clk,
  output logic done
);

  localparam int c_WORDS = colibri_utils::least_common_mult(g_A_WIDTH, g_B_WIDTH)
                           / g_A_WIDTH * g_TEST_SIZE;

  logic [g_A_WIDTH-1:0] snk_data = '0;
  logic                 snk_valid = 1'b0;
  logic                 snk_ready;
  logic [g_B_WIDTH-1:0] gbx_data;
  logic                 gbx_valid;
  logic                 gbx_ready;
  logic [g_A_WIDTH-1:0] src_data;
  logic                 src_valid;
  logic                 src_ready = 1'b0;
  logic                 reset = 1'b1;
  logic [g_A_WIDTH-1:0] test_vec;
  int                   n_got = 0;
  int                   src_stall = 0;

  cc_gearbox #(
    .g_INPUT_WIDTH(g_A_WIDTH),
    .g_OUTPUT_WIDTH(g_B_WIDTH)
  ) gearbox_a (
    .snk_clk_i(clk),
    .snk_reset_i(reset),
    .src_clk_i(gbx_clk),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_data_o(gbx_data),
    .src_valid_o(gbx_valid),
    .src_ready_i(gbx_ready)
  );

  cc_gearbox #(
    .g_INPUT_WIDTH(g_B_WIDTH),
    .g_OUTPUT_WIDTH(g_A_WIDTH)
  ) gearbox_b (
    .snk_clk_i(gbx_clk),
    .snk_reset_i(reset),
    .src_clk_i(clk),
    .snk_data_i(gbx_data),
    .snk_valid_i(gbx_valid),
    .snk_ready_o(gbx_ready),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  always @(posedge clk) begin
    if (reset) begin
      src_ready <= 1'b0;
      src_stall <= 0;
    end else begin
      if (src_valid && src_ready && (n_got < c_WORDS)) begin
        if (src_data != test_vec)
          $fatal(1, "cc_gearbox_loop a=%0d b=%0d: mismatch got %h exp %h",
                 g_A_WIDTH, g_B_WIDTH, src_data, test_vec);
        n_got <= n_got + 1;
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

  task automatic send_word;
    int guard;
    @(negedge clk);
    if ($urandom_range(0, 1) == 1)
      repeat ($urandom_range(1, 8)) @(posedge clk);
    @(negedge clk);
    snk_data  = test_vec;
    snk_valid = 1'b1;
    guard = 0;
    @(posedge clk);
    while (!(snk_valid && snk_ready)) begin
      @(posedge clk);
      guard++;
      if (guard > 2000000)
        $fatal(1, "cc_gearbox_loop a=%0d b=%0d: sink timeout", g_A_WIDTH, g_B_WIDTH);
    end
    @(negedge clk);
    snk_valid = 1'b0;
  endtask

  initial begin
    done = 1'b0;
    for (int b = 0; b < g_A_WIDTH; b++)
      test_vec[b] = 1'($urandom_range(0, 1));
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (3) @(posedge clk);
    for (int i = 0; i < c_WORDS; i++)
      send_word();
    begin
      int guard;
      guard = 0;
      while (n_got < c_WORDS) begin
        @(posedge clk);
        guard++;
        if (guard > 4000000)
          $fatal(1, "cc_gearbox_loop a=%0d b=%0d: source timeout got %0d/%0d",
                 g_A_WIDTH, g_B_WIDTH, n_got, c_WORDS);
      end
    end
    done = 1'b1;
  end

endmodule

module cc_gearbox_loopback_tb;

  logic clk = 1'b1;
  logic gbx_clk = 1'b1;
  logic done [0:1][1:128];

  always #2.5 clk = ~clk;
  always #(5.0/7.0) gbx_clk = ~gbx_clk;

  for (genvar ai = 0; ai < 2; ai++) begin : gen_a
    localparam int c_A = (ai == 0) ? 16 : 32;
    for (genvar b = 1; b <= 128; b++) begin : gen_b
      cc_gearbox_loop_case #(
        .g_A_WIDTH(c_A),
        .g_B_WIDTH(b)
      ) u_case (
        .clk(clk),
        .gbx_clk(gbx_clk),
        .done(done[ai][b])
      );
    end
  end

  initial begin
    int n;
    n = 0;
    while (n != 256) begin
      #1000;
      n = 0;
      for (int ai = 0; ai < 2; ai++)
        for (int b = 1; b <= 128; b++)
          if (done[ai][b])
            n++;
    end
    $display("PASS cc_gearbox_loopback_tb");
    $finish;
  end

  initial begin
    #50ms;
    $fatal(1, "timeout cc_gearbox_loopback_tb");
  end

endmodule
