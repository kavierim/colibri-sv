// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Run-length decoder bench. Eleven packets (0..c_TEST_SIZE), each a random
// word in 16..127 so the count field is non-zero. Consecutive data nibbles
// differ, matching the SVA assume. The decoder must repeat the low nibble
// `count` times. Bounded random gaps stall both sides.

`timescale 1ns/1ps

module rle_decode_tb;
  localparam int unsigned G_WORD_WIDTH  = 4;
  localparam int unsigned G_COUNT_WIDTH = 3;
  localparam int          c_TEST_SIZE   = 10;
  localparam int          c_IN_W        = G_WORD_WIDTH + G_COUNT_WIDTH;
  localparam int          c_N           = c_TEST_SIZE + 1;

  logic                    clk       = 1'b0;
  logic                    reset     = 1'b1;
  logic                    snk_ready;
  logic                    snk_valid = 1'b0;
  logic [c_IN_W-1:0]       snk_data  = {3'd1, 4'd1};
  logic                    src_ready = 1'b0;
  logic                    src_valid;
  logic [G_WORD_WIDTH-1:0] src_data;

  always #5 clk = ~clk;

  rle_decode #(
    .g_WORD_WIDTH  (G_WORD_WIDTH),
    .g_COUNT_WIDTH (G_COUNT_WIDTH)
  ) dut (
    .clk_i       (clk),
    .reset_i     (reset),
    .snk_ready_o (snk_ready),
    .snk_valid_i (snk_valid),
    .snk_data_i  (snk_data),
    .src_ready_i (src_ready),
    .src_valid_o (src_valid),
    .src_data_o  (src_data)
  );

  initial begin
    #200us;
    $fatal(1, "rle_decode_tb timeout");
  end

  task automatic step();
    @(posedge clk);
    #1;
  endtask

  task automatic send_pkt(input logic [c_IN_W-1:0] pkt);
    int guard;
    bit hs;
    if ($urandom_range(0, 1) == 0) begin
      snk_valid = 1'b0;
      repeat ($urandom_range(1, 8))
        step();
    end
    snk_data  = pkt;
    snk_valid = 1'b1;
    src_ready = 1'b1;
    guard = 0;
    hs    = 1'b0;
    do begin
      hs = snk_valid && snk_ready;
      step();
      guard++;
    end while (!hs && guard < 40);
    if (!hs)
      $fatal(1, "rle_decode_tb send timeout");
    snk_valid = 1'b0;
  endtask

  function automatic logic [c_IN_W-1:0] draw_pkt(
    input logic [G_WORD_WIDTH-1:0] prev
  );
    logic [c_IN_W-1:0] pkt;
    int                n;
    n   = 0;
    pkt = c_IN_W'($urandom_range(16, 127));
    while ((pkt[G_WORD_WIDTH-1:0] == prev) && (n < 40)) begin
      pkt = c_IN_W'($urandom_range(16, 127));
      n++;
    end
    if (pkt[G_WORD_WIDTH-1:0] == prev)
      $fatal(1, "rle_decode_tb: no distinct data nibble");
    return pkt;
  endfunction

  initial begin : proc_seq
    logic [c_IN_W-1:0]       pkt;
    logic [G_WORD_WIDTH-1:0] prev;
    int                      count;
    int                      i;
    int                      k;
    int                      guard;

    prev = '0;
    repeat (2) @(posedge clk);
    #1;
    reset = 1'b0;
    @(posedge clk);
    #1;

    for (i = 0; i < c_N; i++) begin
      pkt   = draw_pkt(prev);
      prev  = pkt[G_WORD_WIDTH-1:0];
      count = int'(pkt[c_IN_W-1:G_WORD_WIDTH]);
      send_pkt(pkt);

      for (k = 0; k < count; k++) begin
        if ($urandom_range(0, 1) == 0) begin
          src_ready = 1'b0;
          repeat ($urandom_range(1, 8))
            step();
        end
        src_ready = 1'b1;
        guard = 0;
        while (!src_valid && guard < 20) begin
          step();
          guard++;
        end
        if (!src_valid)
          $fatal(1, "rle_decode_tb missing beat %0d of packet %0d", k, i);
        if (src_data != pkt[G_WORD_WIDTH-1:0])
          $fatal(1, "rle_decode_tb mismatch pkt=%0h got=%0h", pkt, src_data);
        step();
      end
      if (src_valid)
        $fatal(1, "rle_decode_tb extra valid after packet %0d", i);
    end

    $display("PASS: rle_decode_tb");
    $finish;
  end

endmodule
