// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from gearbox_down_tb.vhdl: 12-bit to 4-bit, master stall 90%, slave stall 1%.

`timescale 1ns/1ps

module gearbox_down_tb;

  localparam int c_IN = 12;
  localparam int c_OUT = 4;

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
      if (src_valid && src_ready && (n_got < 12)) begin
        if (src_data != c_OUT'(n_got))
          $fatal(1, "gearbox_down: data mismatch got %h exp %h", src_data, c_OUT'(n_got));
        n_got <= n_got + 1;
      end
      if (src_stall > 0) begin
        src_ready <= 1'b0;
        src_stall <= src_stall - 1;
      end else begin
        src_ready <= 1'b1;
        if (src_valid && src_ready && ($urandom_range(0, 99) < 1))
          src_stall <= $urandom_range(1, 8);
      end
    end
  end

  task automatic send_word(input logic [c_IN-1:0] word);
    int guard;
    @(negedge clk);
    if ($urandom_range(0, 99) < 90)
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
        $fatal(1, "gearbox_down: sink ready timeout");
    end
    @(negedge clk);
    snk_valid = 1'b0;
  endtask

  initial begin
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (3) @(posedge clk);
    for (int i = 0; i < 4; i++)
      send_word({c_OUT'(i * 3), c_OUT'(i * 3 + 1), c_OUT'(i * 3 + 2)});
    begin
      int guard;
      guard = 0;
      while (n_got < 12) begin
        @(posedge clk);
        guard++;
        if (guard > 100000)
          $fatal(1, "gearbox_down: source timeout");
      end
    end
    repeat (100) @(posedge clk);
    $display("PASS gearbox_down_tb");
    $finish;
  end

  initial begin
    #1ms;
    $fatal(1, "timeout gearbox_down_tb");
  end

endmodule
