// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/cc_ram_fifo_tb.vhdl.
// Width pairs 8/16/32. Payload is split into the minimum-width units, MSB first.

`timescale 1ns/1ps

module cc_ram_fifo_tb;

  localparam int c_NUM_WORDS = 8;
  localparam int c_N_W       = 3;
  localparam int c_N_CFG     = c_N_W * c_N_W;
  localparam int c_WIDTHS [0:c_N_W-1] = '{8, 16, 32};

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS cc_ram_fifo_tb");
    $finish;
  end

  initial begin
    #2_000_000;
    if (!(&done))
      $fatal(1, "cc_ram_fifo_tb: timeout %b", done);
  end

  for (genvar iw = 0; iw < c_N_W; iw++) begin : gen_w
    for (genvar ir = 0; ir < c_N_W; ir++) begin : gen_r
      localparam int g_INPUT_WIDTH  = c_WIDTHS[iw];
      localparam int g_OUTPUT_WIDTH = c_WIDTHS[ir];
      localparam int c_MEM_WIDTH = (g_INPUT_WIDTH < g_OUTPUT_WIDTH) ? g_INPUT_WIDTH : g_OUTPUT_WIDTH;
      localparam int c_WR_RATIO  = g_INPUT_WIDTH / c_MEM_WIDTH;
      localparam int c_RD_RATIO  = g_OUTPUT_WIDTH / c_MEM_WIDTH;
      localparam int c_IDX = iw * c_N_W + ir;
      localparam int c_QN = 2048;

      logic reset = 1'b1;
      logic wrclk = 1'b0;
      logic rdclk = 1'b0;
      logic [g_INPUT_WIDTH-1:0] data = '0;
      logic wrreq = 1'b0;
      logic rdreq = 1'b0;
      logic [g_OUTPUT_WIDTH-1:0] q;
      logic wrempty, wrfull, rdempty, rdfull;

      always #5 wrclk = ~wrclk;
      always #5.5 rdclk = ~rdclk;

      cc_ram_fifo #(
        .g_NUM_WORDS(c_NUM_WORDS),
        .g_INPUT_WIDTH(g_INPUT_WIDTH),
        .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH)
      ) dut (
        .reset_i(reset),
        .wrclk_i(wrclk),
        .data_i(data),
        .wrreq_i(wrreq),
        .wrusedw_o(),
        .wrempty_o(wrempty),
        .wrfull_o(wrfull),
        .rdclk_i(rdclk),
        .rdreq_i(rdreq),
        .q_o(q),
        .rdusedw_o(),
        .rdempty_o(rdempty),
        .rdfull_o(rdfull)
      );

      logic [c_MEM_WIDTH-1:0] unit_q [0:c_QN-1];
      int nwr, nrd;
      int bin3, bin4, bin5, bin6, bin7;
      bit writers_done;
      bit fill_done;
      logic [g_OUTPUT_WIDTH-1:0] exp_q;
      logic exp_valid;

      always @(posedge wrclk) begin
        if (reset) begin
          nwr <= 0;
        end else if (wrreq && !wrfull) begin
          for (int i = 0; i < c_WR_RATIO; i++)
            unit_q[(nwr + i) % c_QN] <= data[(g_INPUT_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH];
          nwr <= nwr + c_WR_RATIO;
        end
      end

      always @(posedge rdclk) begin
        if (reset) begin
          nrd       <= 0;
          exp_valid <= 1'b0;
        end else begin
          if (exp_valid) begin
            if (q !== exp_q)
              $fatal(1, "cc_ram_fifo_tb w=%0d r=%0d got %h exp %h", g_INPUT_WIDTH, g_OUTPUT_WIDTH, q, exp_q);
            exp_valid <= 1'b0;
          end
          if (rdreq && !rdempty) begin
            if ((nwr - nrd) < c_RD_RATIO)
              $fatal(1, "cc_ram_fifo_tb w=%0d r=%0d underflow", g_INPUT_WIDTH, g_OUTPUT_WIDTH);
            for (int i = 0; i < c_RD_RATIO; i++)
              exp_q[(g_OUTPUT_WIDTH - 1) - (i * c_MEM_WIDTH) -: c_MEM_WIDTH] <= unit_q[(nrd + i) % c_QN];
            nrd       <= nrd + c_RD_RATIO;
            exp_valid <= 1'b1;
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
        fill_done = 1'b0;
        repeat (6) @(posedge wrclk);
        @(negedge wrclk);
        reset = 1'b0;
        repeat (8) @(posedge wrclk);
        // Fill while the reader is idle so write-while-full is reached even
        // when the read port is wider than the write port.
        for (int n = 0; n < 64; n++) begin
          @(negedge wrclk);
          wrreq = 1'b1;
          data  = g_INPUT_WIDTH'($urandom);
          @(posedge wrclk);
          if (wrfull)
            break;
        end
        repeat (4) begin
          @(negedge wrclk);
          wrreq = 1'b1;
          data  = g_INPUT_WIDTH'($urandom);
          @(posedge wrclk);
        end
        @(negedge wrclk);
        wrreq = 1'b0;
        fill_done = 1'b1;
        for (int n = 0; n < 40; n++) begin
          @(negedge wrclk);
          wrreq = 1'($urandom_range(0, 1));
          data  = g_INPUT_WIDTH'($urandom);
          @(posedge wrclk);
          @(negedge wrclk);
          wrreq = 1'b0;
          repeat ($urandom_range(0, 2)) @(posedge wrclk);
        end
        for (int n = 0; n < c_NUM_WORDS + 3; n++) begin
          @(negedge wrclk);
          wrreq = 1'b1;
          data  = g_INPUT_WIDTH'($urandom);
          @(posedge wrclk);
        end
        @(negedge wrclk);
        wrreq = 1'b0;
        writers_done = 1'b1;
      end

      initial begin
        @(negedge reset);
        wait (fill_done);
        repeat (4) @(posedge rdclk);
        for (int n = 0; n < 80; n++) begin
          @(negedge rdclk);
          rdreq = 1'($urandom_range(0, 1));
          @(posedge rdclk);
          @(negedge rdclk);
          rdreq = 1'b0;
          repeat ($urandom_range(0, 2)) @(posedge rdclk);
        end
        @(negedge rdclk);
        rdreq = 1'b1;
        for (int n = 0; n < 80; n++) begin
          @(posedge rdclk);
          if (writers_done && rdempty)
            break;
        end
        @(negedge rdclk);
        rdreq = 1'b0;
        repeat (4) @(posedge rdclk);
        if (!rdempty)
          $fatal(1, "cc_ram_fifo_tb w=%0d r=%0d not empty", g_INPUT_WIDTH, g_OUTPUT_WIDTH);
        if ((nwr - nrd) >= c_RD_RATIO)
          $fatal(1, "cc_ram_fifo_tb w=%0d r=%0d leftover %0d", g_INPUT_WIDTH, g_OUTPUT_WIDTH, nwr - nrd);
        if ((bin3 < 1) || (bin4 < 1) || (bin5 < 1) || (bin6 < 1) || (bin7 < 1))
          $fatal(1, "cc_ram_fifo_tb w=%0d r=%0d coverage %0d %0d %0d %0d %0d",
                 g_INPUT_WIDTH, g_OUTPUT_WIDTH, bin3, bin4, bin5, bin6, bin7);
        done[c_IDX] = 1'b1;
      end
    end
  end

endmodule
