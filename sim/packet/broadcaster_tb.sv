// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// simple: one packet is copied to every output.
// randomize: sizes 1..g_PACKET_SIZE, g_N_PACKETS hits of each size, matching
// AddBins(..., g_N_PACKETS, GenBin(1, g_PACKET_SIZE)).

`timescale 1ns/1ps

import packet_tb_pkg::*;

module broadcaster_tb;
  localparam int unsigned g_NUM_OUTPUTS = 3;
  localparam int unsigned g_DATA_WIDTH  = 32;
  localparam int unsigned g_N_PACKETS   = 5;
  localparam int unsigned g_PACKET_SIZE = 16;
  localparam int c_DATA_W  = int'(g_DATA_WIDTH);
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, 8);
  localparam int c_WORD_B  = c_DATA_W / 8;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic snk_sop_i, snk_eop_i, snk_valid_i, snk_ready_o;
  logic [c_DATA_W-1:0]  snk_data_i;
  logic [c_EMPTY_W-1:0] snk_empty_i;
  logic [g_NUM_OUTPUTS-1:0] src_sop_o, src_eop_o, src_valid_o, src_ready_i;
  logic [c_DATA_W-1:0]  src_data_o [g_NUM_OUTPUTS-1:0];
  logic [c_EMPTY_W-1:0] src_empty_o [g_NUM_OUTPUTS-1:0];

  // Fixed arrays: Verilator 5.020 miscompiles an array of queues.
  logic [7:0] exp_mem [0:31];
  int         exp_n;
  logic [7:0] got_mem [0:g_NUM_OUTPUTS-1][0:31];
  int         got_n [0:g_NUM_OUTPUTS-1];
  bit         mon_on;
  bit         saw_eop [0:g_NUM_OUTPUTS-1];

  always #5 clk = ~clk;

  broadcaster #(
    .g_NUM_OUTPUTS (g_NUM_OUTPUTS),
    .g_DATA_WIDTH  (g_DATA_WIDTH)
  ) u_dut (
    .clk_i       (clk),
    .reset_i     (reset),
    .snk_sop_i   (snk_sop_i),
    .snk_eop_i   (snk_eop_i),
    .snk_valid_i (snk_valid_i),
    .snk_ready_o (snk_ready_o),
    .snk_data_i  (snk_data_i),
    .snk_empty_i (snk_empty_i),
    .src_sop_o   (src_sop_o),
    .src_eop_o   (src_eop_o),
    .src_valid_o (src_valid_o),
    .src_ready_i (src_ready_i),
    .src_data_o  (src_data_o),
    .src_empty_o (src_empty_o)
  );

  initial begin
    if (g_NUM_OUTPUTS >= 4)
      $fatal(1, "Cannot instantiate more than 4 sinks");
  end

  task automatic sample();
    int oi;
    int bi;
    int n_valid;
    if (!mon_on)
      return;
    for (oi = 0; oi < g_NUM_OUTPUTS; oi++) begin
      if (!(src_valid_o[oi] && src_ready_i[oi]))
        continue;
      if (int'(src_empty_o[oi]) >= c_WORD_B)
        $fatal(1, "broadcaster empty %0d on %0d", src_empty_o[oi], oi);
      n_valid = c_WORD_B - int'(src_empty_o[oi]);
      if (got_n[oi] == 0 && !src_sop_o[oi])
        $fatal(1, "broadcaster ch %0d missing sop", oi);
      for (bi = 0; bi < n_valid; bi++) begin
        got_mem[oi][got_n[oi]] = 8'(be_get(256'(src_data_o[oi]), bi, 8, c_WORD_B));
        got_n[oi]++;
      end
      if (src_eop_o[oi]) begin
        if (got_n[oi] != exp_n)
          $fatal(1, "broadcaster ch %0d len got %0d exp %0d", oi, got_n[oi], exp_n);
        for (bi = 0; bi < exp_n; bi++) begin
          if (got_mem[oi][bi] != exp_mem[bi])
            $fatal(1, "broadcaster ch %0d byte %0d got %02x exp %02x",
                   oi, bi, got_mem[oi][bi], exp_mem[bi]);
        end
        saw_eop[oi] = 1'b1;
      end
    end
  endtask

  task automatic clock();
    @(posedge clk);
    sample();
  endtask

  task automatic send_and_check(input int unsigned nbytes);
    int unsigned idx;
    int unsigned n;
    int unsigned bi;
    int unsigned gap;
    int oi;
    exp_n = int'(nbytes);
    for (bi = 0; bi < nbytes; bi++)
      exp_mem[bi] = urand8();
    for (oi = 0; oi < g_NUM_OUTPUTS; oi++) begin
      got_n[oi] = 0;
      saw_eop[oi] = 1'b0;
    end
    idx = 0;
    while (idx < nbytes) begin
      n = nbytes - idx;
      if (n > c_WORD_B)
        n = c_WORD_B;
      @(negedge clk);
      snk_valid_i = 1'b1;
      snk_sop_i   = (idx == 0);
      snk_eop_i   = (idx + n == nbytes);
      snk_data_i  = '0;
      for (bi = 0; bi < n; bi++)
        snk_data_i = c_DATA_W'(be_put(256'(snk_data_i), 32'(exp_mem[idx + bi]), int'(bi), 8, c_WORD_B));
      snk_empty_i = c_EMPTY_W'(c_WORD_B - n);
      do
        clock();
      while (!snk_ready_o);
      idx += n;
      gap = urand(0, 2);
      for (bi = 0; bi < gap; bi++) begin
        @(negedge clk);
        snk_valid_i = 1'b0;
        snk_eop_i   = 1'b0;
        snk_sop_i   = (idx == nbytes);
        clock();
      end
    end
    @(negedge clk);
    snk_valid_i = 1'b0;
    snk_eop_i   = 1'b0;
    snk_sop_i   = 1'b1;
    while (!(saw_eop[0] && saw_eop[1] && saw_eop[2]))
      clock();
  endtask

  initial begin
    int unsigned sz;
    int unsigned rep;
    mon_on      = 1'b0;
    snk_sop_i   = 1'b1;
    snk_eop_i   = 1'b0;
    snk_valid_i = 1'b0;
    snk_data_i  = '0;
    snk_empty_i = '0;
    src_ready_i = '1;
    seed_rand(32'hB0AD_0001);
    @(posedge clk);
    wait (reset == 1'b0);
    @(posedge clk);
    mon_on = 1'b1;
    send_and_check(g_PACKET_SIZE);
    for (sz = 1; sz <= g_PACKET_SIZE; sz++) begin
      for (rep = 0; rep < g_N_PACKETS; rep++)
        send_and_check(sz);
    end
    repeat (4) clock();
    $display("PASS broadcaster_tb");
    $finish;
  end

  initial begin
    reset = 1'b1;
    @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
  end

  initial begin
    #20ms;
    $fatal(1, "broadcaster_tb watchdog");
  end
endmodule
