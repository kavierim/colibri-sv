// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/packet_cc_ram_fifo.
// The VHDL harness swaps the width generics onto the DUT, and this bench
// does the same. Each of the four width pairs runs the coverage, drop and
// too-big scenarios.

`timescale 1ns/1ps

module packet_cc_ram_fifo_tb;

  localparam int c_N_PACKETS        = 31;
  localparam int c_MIN_SIZE         = 2;
  localparam int c_TOTAL            = c_MIN_SIZE + c_N_PACKETS;
  localparam int c_MAX_PACKET_BYTES = 32;
  localparam int c_NUM_PACKETS      = 4;
  localparam int c_N_W              = 2;
  localparam int c_N_CFG            = c_N_W * c_N_W;
  localparam int c_WIDTHS [0:1]     = '{16, 32};

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS packet_cc_ram_fifo_tb");
    $finish;
  end

  initial begin
    #5_000_000;
    if (!(&done))
      $fatal(1, "packet_cc_ram_fifo_tb: timeout %b", done);
  end

  for (genvar isnk = 0; isnk < c_N_W; isnk++) begin : gen_snk
    for (genvar isrc = 0; isrc < c_N_W; isrc++) begin : gen_src
      localparam int c_TB_SNK = c_WIDTHS[isnk];
      localparam int c_TB_SRC = c_WIDTHS[isrc];
      localparam int c_DUT_SNK = c_TB_SRC;
      localparam int c_DUT_SRC = c_TB_SNK;
      localparam int c_SNK_SYM = c_DUT_SNK / 8;
      localparam int c_SRC_SYM = c_DUT_SRC / 8;
      localparam int c_SNK_EW  = colibri_utils::downto_width(colibri_utils::log2ceil(c_SNK_SYM));
      localparam int c_SRC_EW  = colibri_utils::downto_width(colibri_utils::log2ceil(c_SRC_SYM));
      localparam int c_SIZE_W  = colibri_utils::downto_width(colibri_utils::log2ceil(c_MAX_PACKET_BYTES * c_NUM_PACKETS));
      localparam int c_IDX     = isnk * c_N_W + isrc;

      logic wrclk = 1'b0;
      logic rdclk = 1'b0;
      logic reset = 1'b1;
      logic snk_ready;
      logic snk_valid = 1'b0;
      logic snk_sop = 1'b0;
      logic snk_eop = 1'b0;
      logic snk_drop = 1'b0;
      logic [c_SNK_EW-1:0] snk_empty = '0;
      logic [c_DUT_SNK-1:0] snk_data = '0;
      logic src_ready = 1'b0;
      logic src_valid, src_sop, src_eop;
      logic [c_SRC_EW-1:0] src_empty;
      logic [c_DUT_SRC-1:0] src_data;
      logic [c_SIZE_W-1:0] src_size;

      always #12.5 wrclk = ~wrclk;
      always #8.333 rdclk = ~rdclk;

      packet_cc_ram_fifo #(
        .g_MAX_PACKET_BYTES(c_MAX_PACKET_BYTES),
        .g_NUM_PACKETS(c_NUM_PACKETS),
        .g_SNK_DATA_WIDTH(c_DUT_SNK),
        .g_SRC_DATA_WIDTH(c_DUT_SRC)
      ) dut (
        .reset_i(reset),
        .snk_clk_i(wrclk),
        .src_clk_i(rdclk),
        .snk_sop_i(snk_sop),
        .snk_eop_i(snk_eop),
        .snk_data_i(snk_data),
        .snk_empty_i(snk_empty),
        .snk_valid_i(snk_valid),
        .snk_ready_o(snk_ready),
        .snk_drop_i(snk_drop),
        .src_sop_o(src_sop),
        .src_eop_o(src_eop),
        .src_data_o(src_data),
        .src_empty_o(src_empty),
        .src_size_o(src_size),
        .src_ready_i(src_ready),
        .src_valid_o(src_valid)
      );

      logic [7:0] expb [$];
      int lens [$];
      bit tx_done;
      int n_expect;

      function automatic logic [7:0] msg_byte(input int idx);
        return 8'(idx % 256);
      endfunction

      task automatic apply_reset();
        snk_valid = 1'b0;
        snk_drop  = 1'b0;
        src_ready = 1'b0;
        tx_done   = 1'b0;
        expb.delete();
        lens.delete();
        reset = 1'b1;
        repeat (8) @(posedge wrclk);
        @(negedge wrclk);
        reset = 1'b0;
        repeat (10) @(posedge wrclk);
      endtask

      task automatic send_bytes(input int nbytes, input int first_idx, input logic drop);
        int nbeats;
        int empty_last;
        int bi;
        nbeats = (nbytes + c_SNK_SYM - 1) / c_SNK_SYM;
        empty_last = nbeats * c_SNK_SYM - nbytes;
        for (int b = 0; b < nbeats; b++) begin
          @(negedge wrclk);
          snk_valid = 1'b1;
          snk_drop  = drop;
          snk_sop   = (b == 0);
          snk_eop   = (b == nbeats - 1);
          snk_empty = snk_eop ? c_SNK_EW'(empty_last) : '0;
          for (int s = 0; s < c_SNK_SYM; s++) begin
            bi = b * c_SNK_SYM + s;
            snk_data[(c_SNK_SYM - 1 - s) * 8 +: 8] =
              (bi < nbytes) ? msg_byte(first_idx - bi) : 8'h00;
          end
          do @(posedge wrclk); while (!snk_ready);
        end
        @(negedge wrclk);
        snk_valid = 1'b0;
        snk_drop  = 1'b0;
      endtask

      task automatic expect_packet(input int nbytes, input int first_idx);
        lens.push_back(nbytes);
        for (int k = 0; k < nbytes; k++)
          expb.push_back(msg_byte(first_idx - k));
      endtask

      task automatic recv_all();
        int got;
        int exp_len;
        int n_got;
        int guard;
        n_got = 0;
        guard = 0;
        src_ready = 1'b1;
        while (n_got < n_expect) begin
          @(negedge rdclk);
          src_ready = ($urandom_range(0, 4) != 0);
          @(posedge rdclk);
          // Sample before the nonblocking update: this edge accepts the
          // word that has been presented since the previous edge.
          guard++;
          if (guard > 80000)
            $fatal(1, "packet_cc_ram_fifo_tb cfg %0d timeout after %0d/%0d", c_IDX, n_got, n_expect);
          if (src_valid && src_ready) begin
            int nvalid;
            if (src_sop) begin
              if (lens.size() == 0)
                $fatal(1, "packet_cc_ram_fifo_tb cfg %0d unexpected sop", c_IDX);
              exp_len = lens.pop_front();
              if (src_size !== c_SIZE_W'(exp_len))
                $fatal(1, "packet_cc_ram_fifo_tb cfg %0d size got %0d exp %0d", c_IDX, src_size, exp_len);
              got = 0;
            end
            nvalid = src_eop ? (c_SRC_SYM - int'(src_empty)) : c_SRC_SYM;
            for (int s = 0; s < nvalid; s++) begin
              logic [7:0] exp;
              logic [7:0] gotb;
              if (expb.size() == 0)
                $fatal(1, "packet_cc_ram_fifo_tb cfg %0d extra byte", c_IDX);
              exp  = expb.pop_front();
              gotb = src_data[(c_SRC_SYM - 1 - s) * 8 +: 8];
              if (gotb !== exp)
                $fatal(1, "packet_cc_ram_fifo_tb cfg %0d pkt %0d byte %0d sop %0b eop %0b empty %0d data %h got %h exp %h",
                       c_IDX, n_got, got, src_sop, src_eop, src_empty, src_data, gotb, exp);
              got++;
            end
            if (src_eop) begin
              if (got != exp_len)
                $fatal(1, "packet_cc_ram_fifo_tb cfg %0d length got %0d exp %0d", c_IDX, got, exp_len);
              n_got++;
            end
          end
        end
        src_ready = 1'b0;
      endtask

      initial begin
        apply_reset();
        n_expect = c_N_PACKETS + 1;
        fork
          begin
            for (int i = 0; i < n_expect; i++) begin
              expect_packet(c_TOTAL - i, c_TOTAL - 1);
              send_bytes(c_TOTAL - i, c_TOTAL - 1, 1'b0);
            end
            tx_done = 1'b1;
          end
          begin
            recv_all();
          end
        join

        apply_reset();
        n_expect = (c_N_PACKETS + 1) / 2;
        fork
          begin
            for (int i = 0; i <= c_N_PACKETS; i++) begin
              if ((i % 2) == 0) begin
                expect_packet(c_TOTAL - i, c_TOTAL - 1);
                send_bytes(c_TOTAL - i, c_TOTAL - 1, 1'b0);
              end else begin
                send_bytes(c_TOTAL - i, c_TOTAL - 1, 1'b1);
              end
            end
          end
          begin
            recv_all();
          end
        join

        apply_reset();
        n_expect = 1;
        fork
          begin
            send_bytes(512, 511, 1'b0);
            expect_packet(c_TOTAL, c_TOTAL - 1);
            send_bytes(c_TOTAL, c_TOTAL - 1, 1'b0);
          end
          begin
            recv_all();
          end
        join
        done[c_IDX] = 1'b1;
      end
    end
  end

endmodule
