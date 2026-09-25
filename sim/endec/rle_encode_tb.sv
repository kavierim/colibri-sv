// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Run-length encoder bench. Eleven groups (0..c_TEST_SIZE), each a random
// 4-bit symbol different from the previous one, repeated RandInt(1, COUNT-1)
// times. Bounded random gaps stall the source and the sink. The last group
// is flushed. Each encoded word is {count, data}.

`timescale 1ns/1ps

module rle_encode_tb;
  localparam int unsigned G_WORD_WIDTH  = 4;
  localparam int unsigned G_COUNT_WIDTH = 3;
  localparam int          c_TEST_SIZE   = 10;
  localparam int          c_OUT_W       = G_WORD_WIDTH + G_COUNT_WIDTH;
  localparam int          c_N           = c_TEST_SIZE + 1;

  logic                          clk       = 1'b0;
  logic                          reset     = 1'b1;
  logic                          flush     = 1'b0;
  logic                          snk_ready;
  logic                          snk_valid = 1'b0;
  logic [G_WORD_WIDTH-1:0]       snk_data  = '0;
  logic                          src_ready = 1'b0;
  logic                          src_valid;
  logic [c_OUT_W-1:0]            src_data;

  always #5 clk = ~clk;

  rle_encode #(
    .g_WORD_WIDTH  (G_WORD_WIDTH),
    .g_COUNT_WIDTH (G_COUNT_WIDTH)
  ) dut (
    .clk_i       (clk),
    .reset_i     (reset),
    .flush_i     (flush),
    .snk_ready_o (snk_ready),
    .snk_valid_i (snk_valid),
    .snk_data_i  (snk_data),
    .src_ready_i (src_ready),
    .src_valid_o (src_valid),
    .src_data_o  (src_data)
  );

  logic [c_OUT_W-1:0] exp_q [0:c_N-1];
  logic [c_OUT_W-1:0] got_q [0:c_N-1];
  int                 got_n;

  initial begin
    #200us;
    $fatal(1, "rle_encode_tb timeout");
  end

  task automatic step_cap();
    logic              hs;
    logic [c_OUT_W-1:0] data;
    hs   = src_valid && src_ready;
    data = src_data;
    @(posedge clk);
    #1;
    if (hs) begin
      if (got_n >= c_N)
        $fatal(1, "rle_encode_tb extra output %0h", data);
      got_q[got_n] = data;
      got_n++;
    end
  endtask

  task automatic send_word(input logic [G_WORD_WIDTH-1:0] data);
    int guard;
    bit hs;
    if ($urandom_range(0, 1) == 0) begin
      snk_valid = 1'b0;
      src_ready = 1'b0;
      repeat ($urandom_range(1, 8))
        step_cap();
    end
    snk_data  = data;
    snk_valid = 1'b1;
    src_ready = 1'b1;
    guard = 0;
    hs    = 1'b0;
    do begin
      hs = snk_valid && snk_ready;
      step_cap();
      guard++;
    end while (!hs && guard < 40);
    if (!hs)
      $fatal(1, "rle_encode_tb send timeout");
    snk_valid = 1'b0;
  endtask

  function automatic logic [G_WORD_WIDTH-1:0] draw_data(
    input logic [G_WORD_WIDTH-1:0] prev,
    input logic                    use_prev
  );
    logic [G_WORD_WIDTH-1:0] d;
    int                      n;
    d = G_WORD_WIDTH'($urandom_range(0, 15));
    if (use_prev) begin
      n = 0;
      while ((d == prev) && (n < 16)) begin
        d = G_WORD_WIDTH'($urandom_range(0, 15));
        n++;
      end
      if (d == prev)
        $fatal(1, "rle_encode_tb: no distinct symbol");
    end
    return d;
  endfunction

  initial begin : proc_seq
    logic [G_WORD_WIDTH-1:0] data;
    logic [G_WORD_WIDTH-1:0] prev;
    int                      cnt;
    int                      i;
    int                      k;
    logic                    use_prev;

    got_n   = 0;
    prev    = '0;
    use_prev = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    reset = 1'b0;
    @(posedge clk);
    #1;

    for (i = 0; i < c_N; i++) begin
      data = draw_data(prev, use_prev);
      cnt  = $urandom_range(1, G_COUNT_WIDTH - 1);
      exp_q[i] = {G_COUNT_WIDTH'(cnt), data};
      for (k = 0; k < cnt; k++)
        send_word(data);
      prev     = data;
      use_prev = 1'b1;
    end

    snk_valid = 1'b0;
    src_ready = 1'b1;
    flush     = 1'b0;
    repeat (6) step_cap();
    if (src_valid)
      $fatal(1, "rle_encode_tb src_valid still high before flush");

    flush = 1'b1;
    begin
      int guard;
      guard = 0;
      while ((got_n < c_N) && (guard < 16)) begin
        step_cap();
        guard++;
      end
    end
    repeat (6) step_cap();
    flush     = 1'b0;
    src_ready = 1'b0;

    if (got_n != c_N)
      $fatal(1, "rle_encode_tb got %0d words, expected %0d", got_n, c_N);
    for (i = 0; i < c_N; i++) begin
      if (got_q[i] != exp_q[i])
        $fatal(1, "rle_encode_tb mismatch [%0d] exp=%0h got=%0h", i, exp_q[i], got_q[i]);
    end

    $display("PASS: rle_encode_tb");
    $finish;
  end

endmodule
