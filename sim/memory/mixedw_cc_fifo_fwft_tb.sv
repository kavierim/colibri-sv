// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/mixedw_cc_fifo_fwft_tb.vhdl.
// Same widths as mixedw_cc_fifo_tb, with g_ENABLE_FWFT. q is checked on the
// read edge, which is the value q_delay samples in the VHDL bench.

`timescale 1ns/1ps

module mixedw_cc_fifo_fwft_tb;

  localparam int c_NUM_WORDS   = 40;
  localparam int c_WNUM_WORDS  = 4;
  localparam int c_WDATA_WIDTH = 12;
  localparam int c_RDATA_WIDTH = 8;
  localparam int c_BUF_UNIT    = 4;
  localparam int c_WR_UNITS    = 3;
  localparam int c_RD_UNITS    = 2;
  localparam int c_QN          = 1024;

  logic reset = 1'b1;
  logic wrclk = 1'b0;
  logic rdclk = 1'b0;
  logic [c_WDATA_WIDTH-1:0] data = '0;
  logic wrreq = 1'b0;
  logic rdreq = 1'b0;
  logic [c_RDATA_WIDTH-1:0] q;
  logic [c_WDATA_WIDTH-1:0] wrq;
  logic wrq_valid;
  logic wrempty, wrfull, rdempty, rdfull;

  always #5 wrclk = ~wrclk;
  always #11.5 rdclk = ~rdclk;

  cc_fifo #(
    .g_NUM_WORDS(c_WNUM_WORDS),
    .g_INPUT_WIDTH(c_WDATA_WIDTH),
    .g_OUTPUT_WIDTH(c_RDATA_WIDTH),
    .g_ENABLE_FWFT(1'b1)
  ) cc_fifo_inst (
    .wrclk_i(wrclk),
    .rdclk_i(rdclk),
    .reset_i(reset),
    .data_i(data),
    .wrreq_i(wrreq),
    .rdreq_i(rdreq),
    .q_o(q),
    .wrusedw_o(),
    .rdusedw_o(),
    .wrempty_o(wrempty),
    .wrfull_o(wrfull),
    .rdempty_o(rdempty),
    .rdfull_o(rdfull),
    .wrq_o(wrq),
    .wrq_valid_o(wrq_valid)
  );

  logic [c_BUF_UNIT-1:0] nib [0:c_QN-1];
  int nwr, nrd;
  int bin1, bin2, bin3, bin4, bin5, bin6, bin7;
  bit writers_done;
  bit fill_done;

  always @(posedge wrclk) begin
    if (reset) begin
      nwr  <= 0;
      bin1 <= 0;
      bin2 <= 0;
      bin3 <= 0;
      bin4 <= 0;
      bin5 <= 0;
      bin6 <= 0;
      bin7 <= 0;
    end else begin
      if (wrreq && wrempty) bin1 <= bin1 + 1;
      if (rdreq && rdfull) bin2 <= bin2 + 1;
      if (rdreq && wrreq && !rdempty && !wrfull) bin3 <= bin3 + 1;
      if (rdreq && !wrreq && !rdempty) bin4 <= bin4 + 1;
      if (!rdreq && wrreq && !wrfull) bin5 <= bin5 + 1;
      if (wrreq && wrfull) bin6 <= bin6 + 1;
      if (rdreq && rdempty) bin7 <= bin7 + 1;
      if (wrreq && !wrfull) begin
        for (int i = 0; i < c_WR_UNITS; i++)
          nib[(nwr + i) % c_QN] <= data[(c_WDATA_WIDTH - 1) - (c_BUF_UNIT * i) -: c_BUF_UNIT];
        nwr <= nwr + c_WR_UNITS;
      end
    end
  end

  always @(posedge rdclk) begin
    if (reset) begin
      nrd <= 0;
    end else if (rdreq && !rdempty) begin
      logic [c_RDATA_WIDTH-1:0] exp;
      if ((nwr - nrd) < c_RD_UNITS)
        $fatal(1, "mixedw_cc_fifo_fwft_tb: underflow");
      exp = '0;
      for (int i = 0; i < c_RD_UNITS; i++)
        exp[(c_RDATA_WIDTH - 1) - (c_BUF_UNIT * i) -: c_BUF_UNIT] = nib[(nrd + i) % c_QN];
      if (q !== exp)
        $fatal(1, "mixedw_cc_fifo_fwft_tb: data mismatch got %h exp %h", q, exp);
      nrd <= nrd + c_RD_UNITS;
    end
  end

  initial begin
    writers_done = 1'b0;
    fill_done = 1'b0;
    repeat (2) @(posedge rdclk);
    repeat (4) @(posedge wrclk);
    @(negedge wrclk);
    reset = 1'b0;
    repeat (6) @(posedge wrclk);
    for (int i = 0; i < 16; i++) begin
      @(negedge wrclk);
      wrreq = 1'b1;
      data  = c_WDATA_WIDTH'($urandom_range(0, 4095));
      @(posedge wrclk);
      if (wrfull)
        break;
    end
    repeat (4) begin
      @(negedge wrclk);
      wrreq = 1'b1;
      data  = c_WDATA_WIDTH'($urandom_range(0, 4095));
      @(posedge wrclk);
    end
    @(negedge wrclk);
    wrreq = 1'b0;
    fill_done = 1'b1;
    for (int i = 0; i < c_NUM_WORDS; i++) begin
      @(negedge wrclk);
      wrreq = 1'($urandom_range(0, 1));
      data  = c_WDATA_WIDTH'($urandom_range(0, 4095));
      @(posedge wrclk);
    end
    repeat (c_WNUM_WORDS + 3) begin
      @(negedge wrclk);
      wrreq = 1'b1;
      data  = c_WDATA_WIDTH'($urandom_range(0, 4095));
      @(posedge wrclk);
    end
    @(negedge wrclk);
    wrreq = 1'b0;
    writers_done = 1'b1;
  end

  initial begin
    @(negedge reset);
    wait (fill_done);
    repeat (8) @(posedge rdclk);
    @(posedge rdclk);
    @(negedge rdclk);
    rdreq = 1'b1;
    repeat (3) @(posedge rdclk);
    @(negedge rdclk);
    rdreq = 1'b0;
    for (int i = 0; i < c_NUM_WORDS; i++) begin
      @(negedge rdclk);
      rdreq = 1'($urandom_range(0, 1));
      @(posedge rdclk);
    end
    @(negedge rdclk);
    rdreq = 1'b1;
    for (int i = 0; i < 80; i++) begin
      @(posedge rdclk);
      if (writers_done && rdempty)
        break;
    end
    @(negedge rdclk);
    rdreq = 1'b0;
    repeat (4) @(posedge rdclk);
    if (!rdempty)
      $fatal(1, "mixedw_cc_fifo_fwft_tb: not empty");
    if ((bin1 < 2) || (bin2 < 2) || (bin3 < 1) || (bin4 < 1) || (bin5 < 1) || (bin6 < 1) || (bin7 < 1))
      $fatal(1, "mixedw_cc_fifo_fwft_tb: coverage %0d %0d %0d %0d %0d %0d %0d",
             bin1, bin2, bin3, bin4, bin5, bin6, bin7);
    $display("PASS mixedw_cc_fifo_fwft_tb");
    $finish;
  end

  initial begin
    #500_000;
    $fatal(1, "mixedw_cc_fifo_fwft_tb: timeout");
  end

endmodule
