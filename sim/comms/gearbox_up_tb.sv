// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from gearbox_up_tb.vhdl: 4-bit to 12-bit, master stall 1%, slave stall 90%.

`timescale 1ns/1ps

module gearbox_up_tb;

  localparam int c_IN = 4;
  localparam int c_OUT = 12;

  logic             clk = 1'b1;
  logic             reset = 1'b1;
  logic [c_IN-1:0]  snk_data = '0;
  logic             snk_valid = 1'b0;
  logic             snk_ready;
  logic [c_OUT-1:0] src_data;
  logic             src_valid;
  logic             src_ready = 1'b0;
  int               n_got = 0;
  int               src_stall = 0;
  logic [c_OUT-1:0] exp_q [0:3];

  always #2.5 clk = ~clk;

  gearbox #(
    .g_INPUT_WIDTH(c_IN),
    .g_OUTPUT_WIDTH(c_OUT)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  always @(posedge clk) begin
    if (reset) begin
      src_ready <= 1'b0;
      src_stall <= 0;
    end else begin
      if (src_valid && src_ready && (n_got < 4)) begin
        if (src_data != exp_q[n_got])
          $fatal(1, "gearbox_up: data mismatch got %h exp %h at %0d",
                 src_data, exp_q[n_got], n_got);
        n_got <= n_got + 1;
      end
      if (src_stall > 0) begin
        src_ready <= 1'b0;
        src_stall <= src_stall - 1;
      end else begin
        src_ready <= 1'b1;
        if (src_valid && src_ready && ($urandom_range(0, 99) < 90))
          src_stall <= $urandom_range(1, 8);
      end
    end
  end

  task automatic send_word(input logic [c_IN-1:0] word);
    int guard;
    @(negedge clk);
    if ($urandom_range(0, 99) < 1)
      repeat ($urandom_range(1, 8)) @(posedge clk);
    @(negedge clk);
    snk_data  = word;
    snk_valid = 1'b1;
    guard = 0;
    @(posedge clk);
    while (!(snk_valid && snk_ready)) begin
      @(posedge clk);
      guard++;
      if (guard > 100000)
        $fatal(1, "gearbox_up: sink ready timeout");
    end
    @(negedge clk);
    snk_valid = 1'b0;
  endtask

  initial begin
    for (int i = 0; i < 4; i++)
      exp_q[i] = {c_IN'(i * 3), c_IN'(i * 3 + 1), c_IN'(i * 3 + 2)};
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (3) @(posedge clk);
    for (int i = 0; i < 12; i++)
      send_word(c_IN'(i));
    begin
      int guard;
      guard = 0;
      while (n_got < 4) begin
        @(posedge clk);
        guard++;
        if (guard > 100000)
          $fatal(1, "gearbox_up: source timeout");
      end
    end
    repeat (100) @(posedge clk);
    $display("PASS gearbox_up_tb");
    $finish;
  end

  initial begin
    #1ms;
    $fatal(1, "timeout gearbox_up_tb");
  end

endmodule
