// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/true_dpram_tb.vhdl.
// Sweeps widths 8/16/32 and both implementation styles with write-first.
// Each large-word address is written and read on both ports. The shadow
// memory is indexed the way the RAM concatenates {port_addr, slice}.

`timescale 1ns/1ps

module true_dpram_tb;

  localparam int c_N_WORDS = 8;
  localparam int c_N_W     = 3;
  localparam int c_N_CFG   = c_N_W * c_N_W * 2;
  localparam int c_WIDTHS [0:c_N_W-1] = '{8, 16, 32};

  logic clka = 1'b0;
  logic clkb = 1'b0;
  always #3.5 clka = ~clka;
  always #2.5 clkb = ~clkb;

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS true_dpram_tb");
    $finish;
  end

  initial begin
    #2_000_000;
    if (!(&done))
      $fatal(1, "true_dpram_tb: timeout %b", done);
  end

  for (genvar ia = 0; ia < c_N_W; ia++) begin : gen_a
    for (genvar ib = 0; ib < c_N_W; ib++) begin : gen_b
      for (genvar im = 0; im < 2; im++) begin : gen_impl
        localparam int c_A = c_WIDTHS[ia];
        localparam int c_B = c_WIDTHS[ib];
        localparam int c_MAX = (c_A > c_B) ? c_A : c_B;
        localparam int c_MIN = (c_A < c_B) ? c_A : c_B;
        localparam int c_A_RATIO = c_A / c_MIN;
        localparam int c_B_RATIO = c_B / c_MIN;
        localparam int c_A_AW = colibri_utils::log2ceil(c_N_WORDS * (c_MAX / c_A));
        localparam int c_B_AW = colibri_utils::log2ceil(c_N_WORDS * (c_MAX / c_B));
        localparam int c_DEPTH = c_N_WORDS * c_MAX / c_MIN;
        localparam int c_IDX = (ia * c_N_W + ib) * 2 + im;
        localparam colibri_utils::compiler_t c_STYLE =
          (im == 0) ? colibri_utils::AUTO : colibri_utils::QUARTUS;

        logic wra = 1'b0;
        logic wrb = 1'b0;
        logic [c_A_AW-1:0] addra = '0;
        logic [c_B_AW-1:0] addrb = '0;
        logic [c_A-1:0] dataa = '0;
        logic [c_B-1:0] datab = '0;
        logic [c_A-1:0] qa;
        logic [c_B-1:0] qb;
        logic [c_MIN-1:0] memcell [0:c_DEPTH-1];
        int bin_wa, bin_ra, bin_wb, bin_rb;
        int addr_hit [0:c_N_WORDS-1];

        true_dpram #(
          .g_A_ADDR_WIDTH(c_A_AW),
          .g_B_ADDR_WIDTH(c_B_AW),
          .g_A_DATA_WIDTH(c_A),
          .g_B_DATA_WIDTH(c_B),
          .g_N_WORDS(c_N_WORDS),
          .g_WRITE_FIRST(1'b1),
          .g_IMPL_STYLE(c_STYLE)
        ) dut (
          .clka_i(clka),
          .clkb_i(clkb),
          .wra_i(wra),
          .wrb_i(wrb),
          .addra_i(addra),
          .addrb_i(addrb),
          .dataa_i(dataa),
          .datab_i(datab),
          .dataa_o(qa),
          .datab_o(qb)
        );

        function automatic logic [c_MIN-1:0] slice_at(input logic [c_MAX-1:0] word, input int k, input int width);
          return word[(width - 1) - (k * c_MIN) -: c_MIN];
        endfunction

        initial begin
          bin_wa = 0;
          bin_ra = 0;
          bin_wb = 0;
          bin_rb = 0;
          for (int i = 0; i < c_DEPTH; i++)
            memcell[i] = '0;
          for (int i = 0; i < c_N_WORDS; i++)
            addr_hit[i] = 0;
          repeat (4) @(posedge clka);

          for (int w = 0; w < c_N_WORDS; w++) begin
            logic [c_A-1:0] wa;
            logic [c_B-1:0] wb;
            wa = c_A'($urandom);
            wb = c_B'($urandom);
            addr_hit[w]++;

            @(negedge clka);
            wrb = 1'b0;
            wra = 1'b1;
            if (c_A >= c_B) begin
              addra = c_A_AW'(w);
              dataa = wa;
              for (int k = 0; k < c_A_RATIO; k++)
                memcell[w * c_A_RATIO + k] = wa[(c_A - 1) - (k * c_MIN) -: c_MIN];
            end else begin
              addra = c_A_AW'(w * c_B_RATIO);
              dataa = wa;
              memcell[w * c_B_RATIO] = wa[c_MIN-1:0];
            end
            @(posedge clka);
            #1;
            @(negedge clka);
            wra = 1'b0;
            bin_wa++;
            @(posedge clka);
            #1;
            if (c_A >= c_B) begin
              if (qa !== wa)
                $fatal(1, "true_dpram_tb read A wide a=%0d b=%0d impl=%0d w=%0d got %h exp %h",
                       c_A, c_B, im, w, qa, wa);
            end else if (qa !== c_A'(memcell[w * c_B_RATIO])) begin
              $fatal(1, "true_dpram_tb read A narrow a=%0d b=%0d impl=%0d w=%0d got %h exp %h",
                     c_A, c_B, im, w, qa, memcell[w * c_B_RATIO]);
            end
            bin_ra++;

            @(negedge clkb);
            wra = 1'b0;
            wrb = 1'b1;
            if (c_B >= c_A) begin
              addrb = c_B_AW'(w);
              datab = wb;
              for (int k = 0; k < c_B_RATIO; k++)
                memcell[w * c_B_RATIO + k] = wb[(c_B - 1) - (k * c_MIN) -: c_MIN];
            end else begin
              addrb = c_B_AW'(w * c_A_RATIO);
              datab = wb;
              memcell[w * c_A_RATIO] = wb[c_MIN-1:0];
            end
            @(posedge clkb);
            #1;
            @(negedge clkb);
            wrb = 1'b0;
            bin_wb++;
            @(posedge clkb);
            #1;
            if (c_B >= c_A) begin
              if (qb !== wb)
                $fatal(1, "true_dpram_tb read B wide a=%0d b=%0d impl=%0d w=%0d got %h exp %h",
                       c_A, c_B, im, w, qb, wb);
            end else if (qb !== c_B'(memcell[w * c_A_RATIO])) begin
              $fatal(1, "true_dpram_tb read B narrow a=%0d b=%0d impl=%0d w=%0d got %h exp %h",
                     c_A, c_B, im, w, qb, memcell[w * c_A_RATIO]);
            end
            bin_rb++;
          end

          if ((bin_wa < 1) || (bin_ra < 1) || (bin_wb < 1) || (bin_rb < 1))
            $fatal(1, "true_dpram_tb: bins");
          for (int w = 0; w < c_N_WORDS; w++) begin
            if (addr_hit[w] < 1)
              $fatal(1, "true_dpram_tb: addr %0d uncovered", w);
          end
          done[c_IDX] = 1'b1;
        end
      end
    end
  end

endmodule
