// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/simple_dpram_be_tb.vhdl.
// Byte widths 8 and 9, word sizes 1, 5 and 8. Each write clears the word,
// then applies a random byte-enable mask. The read port checks that image.

`timescale 1ns/1ps

module simple_dpram_be_tb;

  localparam int g_N_WORDS = 64;
  localparam int c_N_BYTE  = 2;
  localparam int c_N_WORD  = 3;
  localparam int c_N_CFG   = c_N_BYTE * c_N_WORD;
  localparam int c_BYTES [0:c_N_BYTE-1] = '{8, 9};
  localparam int c_WORDS [0:c_N_WORD-1] = '{1, 5, 8};

  logic wrclk = 1'b0;
  logic rdclk = 1'b0;
  always #3.5 wrclk = ~wrclk;
  always #5.5 rdclk = ~rdclk;

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS simple_dpram_be_tb");
    $finish;
  end

  initial begin
    #2_000_000;
    if (!(&done))
      $fatal(1, "simple_dpram_be_tb: timeout %b", done);
  end

  for (genvar ib = 0; ib < c_N_BYTE; ib++) begin : gen_byte
    for (genvar iw = 0; iw < c_N_WORD; iw++) begin : gen_word
      localparam int g_BYTE_WIDTH = c_BYTES[ib];
      localparam int g_WORD_BYTES = c_WORDS[iw];
      localparam int c_DATA_W = g_WORD_BYTES * g_BYTE_WIDTH;
      localparam int c_ADDR_W = colibri_utils::log2ceil(g_N_WORDS);
      localparam int c_IDX = ib * c_N_WORD + iw;

      logic [g_WORD_BYTES-1:0] wren = '0;
      logic [c_ADDR_W-1:0] wraddr = '0;
      logic [c_DATA_W-1:0] wrdata = '0;
      logic rden = 1'b0;
      logic [c_ADDR_W-1:0] rdaddr = '0;
      logic [c_DATA_W-1:0] rddata;
      logic [c_DATA_W-1:0] exp_mem [0:g_N_WORDS-1];
      bit pending [0:g_N_WORDS-1];

      simple_dpram_be #(
        .g_BYTE_WIDTH(g_BYTE_WIDTH),
        .g_WORD_BYTES(g_WORD_BYTES),
        .g_N_WORDS(g_N_WORDS)
      ) uut_simple_dpram_be (
        .wrclk_i(wrclk),
        .wren_i(wren),
        .wraddr_i(wraddr),
        .wrdata_i(wrdata),
        .rdclk_i(rdclk),
        .rden_i(rden),
        .rdaddr_i(rdaddr),
        .rddata_o(rddata)
      );

      initial begin
        for (int i = 0; i < g_N_WORDS; i++)
          pending[i] = 1'b0;
        repeat (10) @(posedge wrclk);
        // Two passes of every address: 2*g_N_WORDS masked writes, matching
        // the VHDL loop. The reader of that bench frees an address once it
        // has checked it, so addresses are reused. Each pass here writes the
        // whole depth, then reads it back, then writes it again.
        for (int pass = 0; pass < 2; pass++) begin
          for (int a = 0; a < g_N_WORDS; a++) begin
            logic [c_DATA_W-1:0] exp;
            @(negedge wrclk);
            wren   = {g_WORD_BYTES{1'b1}};
            wraddr = c_ADDR_W'(a);
            wrdata = '0;
            @(posedge wrclk);
            #1;
            exp = '0;
            @(negedge wrclk);
            for (int b = 0; b < g_WORD_BYTES; b++) begin
              logic [g_BYTE_WIDTH-1:0] rb;
              rb = g_BYTE_WIDTH'($urandom);
              wrdata[b*g_BYTE_WIDTH +: g_BYTE_WIDTH] = rb;
              if ($urandom_range(0, 1) == 1) begin
                wren[b] = 1'b1;
                exp[b*g_BYTE_WIDTH +: g_BYTE_WIDTH] = rb;
              end else begin
                wren[b] = 1'b0;
                exp[b*g_BYTE_WIDTH +: g_BYTE_WIDTH] = '0;
              end
            end
            @(posedge wrclk);
            #1;
            exp_mem[a] = exp;
            pending[a] = 1'b1;
          end
          @(negedge wrclk);
          wren = '0;
          for (int a = 0; a < g_N_WORDS; a++) begin
            @(negedge rdclk);
            rdaddr = c_ADDR_W'(a);
            rden = 1'b1;
            @(posedge rdclk);
            #1;
            @(negedge rdclk);
            rden = 1'b0;
            if (rddata !== exp_mem[a])
              $fatal(1, "simple_dpram_be_tb byte=%0d words=%0d addr %0d got %h exp %h",
                     g_BYTE_WIDTH, g_WORD_BYTES, a, rddata, exp_mem[a]);
            pending[a] = 1'b0;
          end
        end
        done[c_IDX] = 1'b1;
      end
    end
  end

endmodule
