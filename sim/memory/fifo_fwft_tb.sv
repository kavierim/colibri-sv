// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/fifo_fwft_tb.vhdl.
// Same coverage bins as fifo_tb, with first-word fall-through.
// The prefetched word is checked while it is on q, before the read edge.
// A simultaneous read and write while empty is avoided: FWFT prefetches that
// write, so rd_ptr moves even though empty_o is still high.

`timescale 1ns/1ps

module fifo_fwft_tb;

  localparam int c_NUM_WORDS  = 8;
  localparam int c_DATA_WIDTH = 8;
  localparam int c_USEDW_W    = colibri_utils::log2ceil(c_NUM_WORDS) + 1;
  localparam int c_RANDOM     = 200;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [c_DATA_WIDTH-1:0] data = '0;
  logic wrreq = 1'b0;
  logic rdreq = 1'b0;
  logic [c_DATA_WIDTH-1:0] q;
  logic [c_USEDW_W-1:0] usedw;
  logic empty;
  logic full;

  always #5 clk = ~clk;

  fifo #(
    .g_NUM_WORDS(c_NUM_WORDS),
    .g_INPUT_WIDTH(c_DATA_WIDTH),
    .g_OUTPUT_WIDTH(c_DATA_WIDTH),
    .g_ENABLE_FWFT(1'b1)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .data_i(data),
    .wrreq_i(wrreq),
    .rdreq_i(rdreq),
    .q_o(q),
    .usedw_o(usedw),
    .empty_o(empty),
    .full_o(full)
  );

  logic [c_DATA_WIDTH-1:0] sb [$];
  int bin1, bin2, bin3, bin4, bin5, bin6, bin7;

  task automatic cycle(input logic wr, input logic rd, input logic [c_DATA_WIDTH-1:0] din);
    logic pre_empty;
    logic pre_full;
    logic do_wr;
    logic do_rd;
    @(negedge clk);
    pre_empty = empty;
    pre_full  = full;
    do_wr = wr;
    do_rd = rd;
    if (pre_empty && do_wr && do_rd)
      do_rd = 1'b0;
    wrreq = do_wr;
    rdreq = do_rd;
    data  = din;
    if (!pre_empty) begin
      if (sb.size() == 0)
        $fatal(1, "fifo_fwft_tb: output valid with empty scoreboard");
      if (q !== sb[0])
        $fatal(1, "fifo_fwft_tb: prefetch mismatch got %h exp %h", q, sb[0]);
    end
    @(posedge clk);
    #1;
    if (do_wr && pre_empty)
      bin1++;
    if (do_rd && pre_full)
      bin2++;
    if (do_rd && do_wr && !pre_empty && !pre_full)
      bin3++;
    if (do_rd && !do_wr && !pre_empty)
      bin4++;
    if (!do_rd && do_wr && !pre_full)
      bin5++;
    if (do_wr && pre_full)
      bin6++;
    if (do_rd && pre_empty)
      bin7++;
    if (do_wr && !pre_full)
      sb.push_back(din);
    if (do_rd && !pre_empty) begin
      if (sb.size() == 0)
        $fatal(1, "fifo_fwft_tb: scoreboard empty on read");
      void'(sb.pop_front());
    end
  endtask

  function automatic bit covered();
    return (bin1 >= 2) && (bin2 >= 2) && (bin3 >= 1) && (bin4 >= 1) &&
           (bin5 >= 1) && (bin6 >= 1) && (bin7 >= 1);
  endfunction

  initial begin
    bin1 = 0;
    bin2 = 0;
    bin3 = 0;
    bin4 = 0;
    bin5 = 0;
    bin6 = 0;
    bin7 = 0;
    @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));
    cycle(1'b0, 1'b0, '0);
    cycle(1'b0, 1'b1, '0);
    cycle(1'b0, 1'b1, '0);
    cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));
    cycle(1'b0, 1'b0, '0);

    while (!full)
      cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));
    cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));
    cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));

    cycle(1'b0, 1'b1, '0);
    while (!full)
      cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));
    cycle(1'b0, 1'b1, '0);

    cycle(1'b1, 1'b1, 8'($urandom_range(0, 255)));
    cycle(1'b0, 1'b1, '0);
    cycle(1'b1, 1'b0, 8'($urandom_range(0, 255)));

    for (int i = 0; i < c_RANDOM; i++)
      cycle(1'($urandom_range(0, 1)), 1'($urandom_range(0, 1)), 8'($urandom_range(0, 255)));

    for (int i = 0; i < (c_NUM_WORDS * 2); i++) begin
      if (empty && (sb.size() == 0))
        break;
      cycle(1'b0, 1'b1, '0);
    end
    cycle(1'b0, 1'b1, '0);

    if (!empty || (sb.size() != 0))
      $fatal(1, "fifo_fwft_tb: not empty after drain empty=%b depth=%0d", empty, sb.size());
    if (!covered())
      $fatal(1, "fifo_fwft_tb: coverage bins %0d %0d %0d %0d %0d %0d %0d",
             bin1, bin2, bin3, bin4, bin5, bin6, bin7);
    $display("PASS fifo_fwft_tb");
    $finish;
  end

  initial begin
    #100_000;
    $fatal(1, "fifo_fwft_tb: timeout");
  end

endmodule
