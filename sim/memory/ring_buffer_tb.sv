// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/ring_buffer_tb.vhdl.
// Hits normal write, overwrite, normal read, empty read and full read/write
// at least five times each, and checks data order with a scoreboard.

`timescale 1ns/1ps

module ring_buffer_tb;

  localparam int c_NUM_WORDS  = 4;
  localparam int c_DATA_WIDTH = 8;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [c_DATA_WIDTH-1:0] snk_data = '0;
  logic snk_valid = 1'b0;
  logic [c_DATA_WIDTH-1:0] src_data;
  logic src_valid;
  logic src_ready = 1'b0;

  always #2.5 clk = ~clk;

  ring_buffer #(
    .g_NUM_WORDS(c_NUM_WORDS),
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) ring_buffer_inst (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  logic [c_DATA_WIDTH-1:0] sb [$];
  int count;
  int bin_norm_wr, bin_overwrite, bin_norm_rd, bin_empty_rd, bin_full_rw;
  int data_val;

  task automatic step(input logic do_wr, input logic do_rd);
    logic reading;
    @(negedge clk);
    snk_valid = do_wr;
    src_ready = do_rd;
    if (do_wr) begin
      snk_data = c_DATA_WIDTH'(data_val);
      data_val++;
    end
    reading = do_rd && src_valid;
    if (src_valid !== (count != 0))
      $fatal(1, "ring_buffer_tb: valid %b count %0d", src_valid, count);
    if (reading) begin
      if (sb.size() == 0)
        $fatal(1, "ring_buffer_tb: read with empty scoreboard, data %h", src_data);
      if (src_data !== sb[0])
        $fatal(1, "ring_buffer_tb: data mismatch got %h exp %h", src_data, sb[0]);
      bin_norm_rd++;
    end else if (do_rd && !src_valid) begin
      bin_empty_rd++;
    end
    @(posedge clk);
    #1;
    if (do_wr && reading) begin
      bin_full_rw++;
      void'(sb.pop_front());
      sb.push_back(snk_data);
    end else if (do_wr && (count >= c_NUM_WORDS)) begin
      bin_overwrite++;
      if (sb.size() == 0)
        $fatal(1, "ring_buffer_tb: overwrite with empty scoreboard");
      void'(sb.pop_front());
      sb.push_back(snk_data);
    end else if (do_wr) begin
      bin_norm_wr++;
      sb.push_back(snk_data);
      count++;
    end else if (reading && (count > 0)) begin
      void'(sb.pop_front());
      count--;
    end
    snk_valid = 1'b0;
    src_ready = 1'b0;
  endtask

  initial begin
    data_val      = 1;
    count         = 0;
    bin_norm_wr   = 0;
    bin_overwrite = 0;
    bin_norm_rd   = 0;
    bin_empty_rd  = 0;
    bin_full_rw   = 0;
    repeat (5) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    repeat (5) step(1'b0, 1'b1);
    repeat (4) step(1'b1, 1'b0);
    step(1'b0, 1'b1);
    step(1'b1, 1'b0);
    repeat (5) step(1'b1, 1'b0);
    repeat (5) step(1'b1, 1'b1);
    repeat (4) step(1'b0, 1'b1);

    for (int i = 0; i < 40; i++)
      step(1'($urandom_range(0, 1)), 1'($urandom_range(0, 1)));

    for (int i = 0; i < c_NUM_WORDS + 2; i++) begin
      if (count == 0)
        break;
      step(1'b0, 1'b1);
    end

    if ((bin_norm_wr < 5) || (bin_overwrite < 5) || (bin_norm_rd < 5) ||
        (bin_empty_rd < 5) || (bin_full_rw < 5))
      $fatal(1, "ring_buffer_tb: coverage %0d %0d %0d %0d %0d",
             bin_norm_wr, bin_overwrite, bin_norm_rd, bin_empty_rd, bin_full_rw);
    if ((count != 0) || (sb.size() != 0))
      $fatal(1, "ring_buffer_tb: leftover count %0d depth %0d", count, sb.size());
    $display("PASS ring_buffer_tb");
    $finish;
  end

  initial begin
    #100_000;
    $fatal(1, "ring_buffer_tb: timeout");
  end

endmodule
