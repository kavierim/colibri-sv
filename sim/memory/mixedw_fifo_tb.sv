// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/mixedw_fifo_tb.vhdl.
// 12-bit writes and 8-bit reads, split on the 4-bit gcd, MSB first.

`timescale 1ns/1ps

module mixedw_fifo_tb;

  localparam int c_NUM_WORDS   = 40;
  localparam int c_WNUM_WORDS  = 4;
  localparam int c_WDATA_WIDTH = 12;
  localparam int c_RDATA_WIDTH = 8;
  localparam int c_BUF_UNIT    = 4;
  localparam int c_WR_UNITS    = c_WDATA_WIDTH / c_BUF_UNIT;
  localparam int c_RD_UNITS    = c_RDATA_WIDTH / c_BUF_UNIT;
  localparam int c_QN          = 512;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [c_WDATA_WIDTH-1:0] data = '0;
  logic wrreq = 1'b0;
  logic rdreq = 1'b0;
  logic [c_RDATA_WIDTH-1:0] q;
  logic empty;
  logic full;
  logic [colibri_utils::log2ceil(c_WNUM_WORDS):0] usedw;

  always #2.5 clk = ~clk;

  fifo #(
    .g_NUM_WORDS(c_WNUM_WORDS),
    .g_INPUT_WIDTH(c_WDATA_WIDTH),
    .g_OUTPUT_WIDTH(c_RDATA_WIDTH),
    .g_ENABLE_FWFT(1'b0)
  ) fifo_inst (
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

  logic [c_BUF_UNIT-1:0] nib [0:c_QN-1];
  int nwr;
  int nrd;
  int bin1, bin2, bin3, bin4, bin5, bin6, bin7;

  task automatic cycle(input logic wr, input logic rd, input logic [c_WDATA_WIDTH-1:0] din);
    logic pre_empty;
    logic pre_full;
    logic [c_RDATA_WIDTH-1:0] exp;
    @(negedge clk);
    wrreq = wr;
    rdreq = rd;
    data  = din;
    pre_empty = empty;
    pre_full  = full;
    @(posedge clk);
    #1;
    if (wr && pre_empty) bin1++;
    if (rd && pre_full) bin2++;
    if (rd && wr && !pre_empty && !pre_full) bin3++;
    if (rd && !wr && !pre_empty) bin4++;
    if (!rd && wr && !pre_full) bin5++;
    if (wr && pre_full) bin6++;
    if (rd && pre_empty) bin7++;
    if (wr && !pre_full) begin
      for (int i = 0; i < c_WR_UNITS; i++) begin
        nib[(nwr + i) % c_QN] = din[(c_WDATA_WIDTH - 1) - (c_BUF_UNIT * i) -: c_BUF_UNIT];
      end
      nwr += c_WR_UNITS;
    end
    if (rd && !pre_empty) begin
      if ((nwr - nrd) < c_RD_UNITS)
        $fatal(1, "mixedw_fifo_tb: underflow");
      exp = '0;
      for (int i = 0; i < c_RD_UNITS; i++)
        exp[(c_RDATA_WIDTH - 1) - (c_BUF_UNIT * i) -: c_BUF_UNIT] = nib[(nrd + i) % c_QN];
      nrd += c_RD_UNITS;
      if (q !== exp)
        $fatal(1, "mixedw_fifo_tb: data mismatch got %h exp %h", q, exp);
    end
  endtask

  initial begin
    nwr = 0;
    nrd = 0;
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

    cycle(1'b0, 1'b1, '0);
    cycle(1'b1, 1'b0, 12'($urandom_range(0, 4095)));
    repeat (3) cycle(1'b0, 1'b0, '0);
    cycle(1'b0, 1'b1, '0);
    cycle(1'b1, 1'b0, 12'($urandom_range(0, 4095)));

    for (int i = 0; i < c_WNUM_WORDS + 2; i++)
      cycle(1'b1, 1'b0, 12'($urandom_range(0, 4095)));
    cycle(1'b1, 1'b0, 12'($urandom_range(0, 4095)));
    cycle(1'b0, 1'b1, '0);
    cycle(1'b1, 1'b1, 12'($urandom_range(0, 4095)));

    for (int i = 0; i < c_NUM_WORDS; i++)
      cycle(1'($urandom_range(0, 1)), 1'($urandom_range(0, 1)), 12'($urandom_range(0, 4095)));

    for (int i = 0; i < 32; i++) begin
      if (empty)
        break;
      cycle(1'b0, 1'b1, '0);
    end
    cycle(1'b0, 1'b1, '0);

    if (!empty)
      $fatal(1, "mixedw_fifo_tb: not empty after drain");
    if ((nwr - nrd) >= c_RD_UNITS)
      $fatal(1, "mixedw_fifo_tb: leftover units %0d", nwr - nrd);
    if ((bin1 < 2) || (bin2 < 2) || (bin3 < 1) || (bin4 < 1) || (bin5 < 1) || (bin6 < 1) || (bin7 < 1))
      $fatal(1, "mixedw_fifo_tb: coverage %0d %0d %0d %0d %0d %0d %0d",
             bin1, bin2, bin3, bin4, bin5, bin6, bin7);
    $display("PASS mixedw_fifo_tb");
    $finish;
  end

  initial begin
    #200_000;
    $fatal(1, "mixedw_fifo_tb: timeout");
  end

endmodule
