// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/cc_fifo_tb.vhdl.
// Both g_ENABLE_FWFT settings are elaborated. Writes and reads are random and
// bounded. Accepted writes are scoreboarded; reads and the write-side peek
// must return that sequence. Coverage matches the VHDL bins.

`timescale 1ns/1ps

module cc_fifo_tb;

  localparam int c_NUM_WORDS  = 8;
  localparam int c_DATA_WIDTH = 8;
  localparam int c_N_CFG      = 2;

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS cc_fifo_tb");
    $finish;
  end

  initial begin
    #1_000_000;
    if (!(&done))
      $fatal(1, "cc_fifo_tb: timeout %b", done);
  end

  for (genvar fi = 0; fi < 2; fi++) begin : gen_fwft
    localparam bit g_ENABLE_FWFT = (fi == 1);

    logic reset = 1'b1;
    logic wrclk = 1'b0;
    logic rdclk = 1'b0;
    logic [c_DATA_WIDTH-1:0] data = '0;
    logic wrreq = 1'b0;
    logic rdreq = 1'b0;
    logic [c_DATA_WIDTH-1:0] q;
    logic [c_DATA_WIDTH-1:0] wrq;
    logic wrq_valid;
    logic wrempty, wrfull, rdempty, rdfull;
    logic [colibri_utils::downto_width(colibri_utils::log2ceil(c_NUM_WORDS))-1:0] wrusedw;
    logic [colibri_utils::downto_width(colibri_utils::log2ceil(c_NUM_WORDS))-1:0] rdusedw;

    always #5 wrclk = ~wrclk;
    always #5.5 rdclk = ~rdclk;

    cc_fifo #(
      .g_NUM_WORDS(c_NUM_WORDS),
      .g_INPUT_WIDTH(c_DATA_WIDTH),
      .g_OUTPUT_WIDTH(c_DATA_WIDTH),
      .g_PEEK_NEXT(1'b1),
      .g_ENABLE_FWFT(g_ENABLE_FWFT)
    ) dut (
      .wrclk_i(wrclk),
      .rdclk_i(rdclk),
      .reset_i(reset),
      .data_i(data),
      .wrreq_i(wrreq),
      .rdreq_i(rdreq),
      .q_o(q),
      .wrusedw_o(wrusedw),
      .rdusedw_o(rdusedw),
      .wrempty_o(wrempty),
      .wrfull_o(wrfull),
      .rdempty_o(rdempty),
      .rdfull_o(rdfull),
      .wrq_o(wrq),
      .wrq_valid_o(wrq_valid)
    );

    logic [c_DATA_WIDTH-1:0] sb [0:1023];
    logic [c_DATA_WIDTH-1:0] peek_sb [0:1023];
    int w_idx, r_idx, peek_w, peek_r;
    int bin3, bin4, bin5, bin6, bin7;
    bit writers_done;
    logic [c_DATA_WIDTH-1:0] exp_q;
    logic exp_valid;

    always @(posedge wrclk) begin
      if (reset) begin
        w_idx  <= 0;
        peek_w <= 0;
      end else if (wrreq && !wrfull) begin
        sb[w_idx[9:0]]      <= data;
        peek_sb[peek_w[9:0]] <= data;
        w_idx  <= w_idx + 1;
        peek_w <= peek_w + 1;
      end
    end

    always @(posedge wrclk) begin
      if (reset) begin
        peek_r <= 0;
      end else if (wrq_valid) begin
        if (peek_r == peek_w)
          $fatal(1, "cc_fifo_tb fwft=%0d peek with empty scoreboard", g_ENABLE_FWFT);
        if (wrq !== peek_sb[peek_r[9:0]])
          $fatal(1, "cc_fifo_tb fwft=%0d peek got %h exp %h", g_ENABLE_FWFT, wrq, peek_sb[peek_r[9:0]]);
        peek_r <= peek_r + 1;
      end
    end

    always @(posedge rdclk) begin
      if (reset) begin
        r_idx     <= 0;
        exp_valid <= 1'b0;
      end else begin
        if (!g_ENABLE_FWFT && exp_valid) begin
          if (q !== exp_q)
            $fatal(1, "cc_fifo_tb fwft=0 data got %h exp %h", q, exp_q);
          exp_valid <= 1'b0;
        end
        if (rdreq && !rdempty) begin
          if (r_idx == w_idx)
            $fatal(1, "cc_fifo_tb fwft=%0d read with empty scoreboard", g_ENABLE_FWFT);
          if (g_ENABLE_FWFT) begin
            if (q !== sb[r_idx[9:0]])
              $fatal(1, "cc_fifo_tb fwft=1 data got %h exp %h", q, sb[r_idx[9:0]]);
          end else begin
            exp_q     <= sb[r_idx[9:0]];
            exp_valid <= 1'b1;
          end
          r_idx <= r_idx + 1;
        end
      end
    end

    always @(posedge wrclk) begin
      if (reset) begin
        bin3 <= 0;
        bin4 <= 0;
        bin5 <= 0;
        bin6 <= 0;
        bin7 <= 0;
      end else begin
        if (rdreq && wrreq && !rdempty && !wrfull) bin3 <= bin3 + 1;
        if (rdreq && !wrreq && !rdempty) bin4 <= bin4 + 1;
        if (!rdreq && wrreq && !wrfull) bin5 <= bin5 + 1;
        if (wrreq && wrfull) bin6 <= bin6 + 1;
        if (rdreq && rdempty) bin7 <= bin7 + 1;
      end
    end

    initial begin
      writers_done = 1'b0;
      repeat (4) @(posedge wrclk);
      repeat (4) @(posedge rdclk);
      @(negedge wrclk);
      reset = 1'b0;
      repeat (8) @(posedge wrclk);

      for (int i = 0; i < 80; i++) begin
        @(negedge wrclk);
        wrreq = 1'($urandom_range(0, 1));
        data  = c_DATA_WIDTH'($urandom_range(0, 255));
        @(posedge wrclk);
      end
      // Push the write side full, then overflow.
      for (int i = 0; i < c_NUM_WORDS + 4; i++) begin
        @(negedge wrclk);
        wrreq = 1'b1;
        data  = c_DATA_WIDTH'($urandom_range(0, 255));
        @(posedge wrclk);
      end
      @(negedge wrclk);
      wrreq = 1'b0;
      writers_done = 1'b1;
    end

    initial begin
      @(negedge reset);
      repeat (6) @(posedge rdclk);
      for (int i = 0; i < 120; i++) begin
        @(negedge rdclk);
        rdreq = 1'($urandom_range(0, 1));
        @(posedge rdclk);
      end
      @(negedge rdclk);
      rdreq = 1'b1;
      for (int i = 0; i < 40; i++) begin
        @(posedge rdclk);
        if (writers_done && rdempty)
          break;
      end
      @(negedge rdclk);
      rdreq = 1'b0;
      repeat (4) @(posedge rdclk);
      if (!rdempty)
        $fatal(1, "cc_fifo_tb fwft=%0d not empty", g_ENABLE_FWFT);
      if (r_idx != w_idx)
        $fatal(1, "cc_fifo_tb fwft=%0d scoreboard left r=%0d w=%0d", g_ENABLE_FWFT, r_idx, w_idx);
      if ((bin3 < 1) || (bin4 < 1) || (bin5 < 1) || (bin6 < 1) || (bin7 < 1))
        $fatal(1, "cc_fifo_tb fwft=%0d coverage %0d %0d %0d %0d %0d",
               g_ENABLE_FWFT, bin3, bin4, bin5, bin6, bin7);
      done[fi] = 1'b1;
    end
  end

endmodule
