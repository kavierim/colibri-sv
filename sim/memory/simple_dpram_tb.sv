// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/simple_dpram_tb.vhdl.
// Sweeps port widths 8/16/32 and both implementation styles. Writes the
// depth, then reads it back with the VHDL MSB-first mixed-width mapping.

`timescale 1ns/1ps

module simple_dpram_tb;

  localparam int c_N_WORDS = 64;
  localparam int c_N_W     = 3;
  localparam int c_N_CFG   = c_N_W * c_N_W * 2;
  localparam int c_WIDTHS [0:c_N_W-1] = '{8, 16, 32};

  logic wrclk = 1'b0;
  logic rdclk = 1'b0;
  always #3.5 wrclk = ~wrclk;
  always #2.5 rdclk = ~rdclk;

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS simple_dpram_tb");
    $finish;
  end

  initial begin
    #2_000_000;
    if (!(&done))
      $fatal(1, "simple_dpram_tb: timeout %b", done);
  end

  for (genvar ia = 0; ia < c_N_W; ia++) begin : gen_a
    for (genvar ib = 0; ib < c_N_W; ib++) begin : gen_b
      for (genvar im = 0; im < 2; im++) begin : gen_impl
        localparam int c_A = c_WIDTHS[ia];
        localparam int c_B = c_WIDTHS[ib];
        localparam int c_MAX = (c_A > c_B) ? c_A : c_B;
        localparam int c_MIN = (c_A < c_B) ? c_A : c_B;
        localparam int c_RATIO = c_MAX / c_MIN;
        localparam int c_WR_AW = colibri_utils::log2ceil(c_N_WORDS * (c_MAX / c_A));
        localparam int c_RD_AW = colibri_utils::log2ceil(c_N_WORDS * (c_MAX / c_B));
        localparam int c_IDX = (ia * c_N_W + ib) * 2 + im;
        localparam colibri_utils::compiler_t c_STYLE =
          (im == 0) ? colibri_utils::AUTO : colibri_utils::QUARTUS;

        logic wren = 1'b0;
        logic rden = 1'b0;
        logic [c_WR_AW-1:0] wraddr = '0;
        logic [c_RD_AW-1:0] rdaddr = '0;
        logic [c_A-1:0] wrdata = '0;
        logic [c_B-1:0] rddata;
        logic [c_A-1:0] sb_data [0:c_N_WORDS-1];
        logic [c_WR_AW-1:0] sb_addr [0:c_N_WORDS-1];
        bit wrote;

        simple_dpram #(
          .g_A_DATA_WIDTH(c_A),
          .g_B_DATA_WIDTH(c_B),
          .g_N_WORDS(c_N_WORDS),
          .g_A_ADDR_WIDTH(c_WR_AW),
          .g_B_ADDR_WIDTH(c_RD_AW),
          .g_IMPL_STYLE(c_STYLE)
        ) dut (
          .wrclk_i(wrclk),
          .rdclk_i(rdclk),
          .wren_i(wren),
          .rden_i(rden),
          .wraddr_i(wraddr),
          .rdaddr_i(rdaddr),
          .wrdata_i(wrdata),
          .rddata_o(rddata)
        );

        initial begin
          repeat (5) @(posedge wrclk);
          for (int i = 0; i < c_N_WORDS; i++) begin
            @(negedge wrclk);
            wren = 1'b1;
            wraddr = c_WR_AW'(i);
            wrdata = c_A'($urandom);
            sb_addr[i] = wraddr;
            sb_data[i] = wrdata;
            @(posedge wrclk);
            #1;
            @(negedge wrclk);
            wren = 1'b0;
            if ($urandom_range(0, 1) == 1)
              @(posedge wrclk);
          end
          @(negedge wrclk);
          wren = 1'b0;
          wrote = 1'b1;
        end

        if (c_B >= c_A) begin : gen_wide_rd
          initial begin
            wait (wrote);
            repeat (4) @(posedge rdclk);
            for (int base = 0; base < c_N_WORDS; base += c_RATIO) begin
              logic [c_B-1:0] expw;
              expw = '0;
              for (int k = 0; k < c_RATIO; k++)
                expw[(c_B - 1) - (k * c_A) -: c_A] = sb_data[base + k];
              @(negedge rdclk);
              rdaddr = c_RD_AW'(int'(sb_addr[base]) / c_RATIO);
              rden = 1'b1;
              @(posedge rdclk);
              #1;
              if (rddata !== expw)
                $fatal(1, "simple_dpram_tb a=%0d b=%0d impl=%0d large addr %h got %h exp %h",
                       c_A, c_B, im, rdaddr, rddata, expw);
              @(negedge rdclk);
              rden = 1'b0;
              @(posedge rdclk);
            end
            done[c_IDX] = 1'b1;
          end
        end else begin : gen_narrow_rd
          initial begin
            wait (wrote);
            repeat (4) @(posedge rdclk);
            for (int base = 0; base < c_N_WORDS; base++) begin
              for (int k = 0; k < c_RATIO; k++) begin
                logic [c_B-1:0] expw;
                expw = sb_data[base][(c_A - 1) - (k * c_B) -: c_B];
                @(negedge rdclk);
                rdaddr = c_RD_AW'((int'(sb_addr[base]) * c_RATIO) + k);
                rden = 1'b1;
                @(posedge rdclk);
                #1;
                if (rddata !== expw)
                  $fatal(1, "simple_dpram_tb a=%0d b=%0d impl=%0d small addr %h got %h exp %h",
                         c_A, c_B, im, rdaddr, rddata, expw);
                @(negedge rdclk);
                rden = 1'b0;
              end
              @(posedge rdclk);
            end
            done[c_IDX] = 1'b1;
          end
        end
      end
    end
  end

endmodule
