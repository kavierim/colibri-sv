// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Loopback of interleaver into deinterleaver. simple and interleave_random
// for word mode and packet-boundary mode. Each input packet returns on the
// matching output.

`timescale 1ns/1ps

import packet_tb_pkg::*;

module interleaver_loopback_case #(
  parameter bit          g_INTERLEAVE_WORDS = 1'b1,
  parameter int unsigned g_NUM_INPUTS       = 3,
  parameter int unsigned g_DATA_WIDTH       = 32,
  parameter int unsigned g_N_PACKETS        = 5,
  parameter int unsigned g_PACKET_SIZE      = 16,
  parameter int unsigned g_SEED             = 32'h10CB_0001
) (
  input  logic clk_i,
  input  logic reset_i,
  output logic done_o
);

  localparam int c_DATA_W  = int'(g_DATA_WIDTH);
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, 8);
  localparam int c_WORD_B  = c_DATA_W / 8;
  localparam int c_CH_W    = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_INPUTS)));

  logic [g_NUM_INPUTS-1:0] snk_sop_i, snk_eop_i, snk_valid_i, snk_ready_o;
  logic [c_DATA_W-1:0]     snk_data_i [g_NUM_INPUTS-1:0];
  logic [c_EMPTY_W-1:0]    snk_empty_i [g_NUM_INPUTS-1:0];
  logic [g_NUM_INPUTS*c_DATA_W-1:0]  snk_data_p;
  logic [g_NUM_INPUTS*c_EMPTY_W-1:0] snk_empty_p;
  logic                    mid_sop, mid_eop, mid_valid, mid_ready;
  logic [c_DATA_W-1:0]     mid_data;
  logic [c_EMPTY_W-1:0]    mid_empty;
  logic [c_CH_W-1:0]       mid_channel;
  logic [g_NUM_INPUTS-1:0] src_sop_o, src_eop_o, src_valid_o, src_ready_i;
  logic [c_DATA_W-1:0]     src_data_o [g_NUM_INPUTS-1:0];
  logic [c_EMPTY_W-1:0]    src_empty_o [g_NUM_INPUTS-1:0];

  localparam int c_CAP  = 1024;
  localparam int c_LCAP = 128;
  logic [7:0] exp_mem [0:g_NUM_INPUTS-1][0:c_CAP-1];
  logic [7:0] tx_mem  [0:g_NUM_INPUTS-1][0:c_CAP-1];
  logic [7:0] got_mem [0:g_NUM_INPUTS-1][0:c_CAP-1];
  int         exp_len_mem [0:g_NUM_INPUTS-1][0:c_LCAP-1];
  int         tx_len_mem  [0:g_NUM_INPUTS-1][0:c_LCAP-1];
  int         exp_rd [0:g_NUM_INPUTS-1];
  int         exp_wr [0:g_NUM_INPUTS-1];
  int         tx_rd  [0:g_NUM_INPUTS-1];
  int         tx_wr  [0:g_NUM_INPUTS-1];
  int         exp_len_rd [0:g_NUM_INPUTS-1];
  int         exp_len_wr [0:g_NUM_INPUTS-1];
  int         tx_len_rd  [0:g_NUM_INPUTS-1];
  int         tx_len_wr  [0:g_NUM_INPUTS-1];
  int         got_n [0:g_NUM_INPUTS-1];
  int         tx_pos [0:g_NUM_INPUTS-1];
  int         tx_left [0:g_NUM_INPUTS-1];
  bit         beat [0:g_NUM_INPUTS-1];
  bit         acc [0:g_NUM_INPUTS-1];
  bit         mon_on;

  interleaver #(
    .g_NUM_INPUTS       (g_NUM_INPUTS),
    .g_DATA_WIDTH       (g_DATA_WIDTH),
    .g_INTERLEAVE_WORDS (g_INTERLEAVE_WORDS)
  ) u_interleaver (
    .clk_i         (clk_i),
    .reset_i       (reset_i),
    .snk_sop_i     (snk_sop_i),
    .snk_eop_i     (snk_eop_i),
    .snk_valid_i   (snk_valid_i),
    .snk_ready_o   (snk_ready_o),
    .snk_data_i    (snk_data_p),
    .snk_empty_i   (snk_empty_p),
    .src_sop_o     (mid_sop),
    .src_eop_o     (mid_eop),
    .src_valid_o   (mid_valid),
    .src_ready_i   (mid_ready),
    .src_data_o    (mid_data),
    .src_empty_o   (mid_empty),
    .src_channel_o (mid_channel)
  );

  deinterleaver #(
    .g_NUM_OUTPUTS (g_NUM_INPUTS),
    .g_DATA_WIDTH  (g_DATA_WIDTH)
  ) u_deinterleaver (
    .clk_i         (clk_i),
    .reset_i       (reset_i),
    .snk_sop_i     (mid_sop),
    .snk_eop_i     (mid_eop),
    .snk_valid_i   (mid_valid),
    .snk_ready_o   (mid_ready),
    .snk_data_i    (mid_data),
    .snk_empty_i   (mid_empty),
    .snk_channel_i (mid_channel),
    .src_sop_o     (src_sop_o),
    .src_eop_o     (src_eop_o),
    .src_valid_o   (src_valid_o),
    .src_ready_i   (src_ready_i),
    .src_data_o    (src_data_o),
    .src_empty_o   (src_empty_o)
  );

  task automatic enqueue(input int ch, input int unsigned nbytes);
    int unsigned bi;
    logic [7:0] b;
    tx_len_mem[ch][tx_len_wr[ch]] = int'(nbytes);
    tx_len_wr[ch]++;
    exp_len_mem[ch][exp_len_wr[ch]] = int'(nbytes);
    exp_len_wr[ch]++;
    for (bi = 0; bi < nbytes; bi++) begin
      b = urand8();
      tx_mem[ch][tx_wr[ch]] = b;
      tx_wr[ch]++;
      exp_mem[ch][exp_wr[ch]] = b;
      exp_wr[ch]++;
    end
  endtask

  function automatic bit tx_idle();
    int ch;
    for (ch = 0; ch < g_NUM_INPUTS; ch++)
      if ((tx_wr[ch] != tx_rd[ch]) || beat[ch] || (exp_len_wr[ch] != exp_len_rd[ch]))
        return 1'b0;
    return 1'b1;
  endfunction

  task automatic sample();
    int ch;
    int bi;
    int n_valid;
    int unsigned elen;
    logic [7:0] gbyte;
    logic [c_DATA_W-1:0] data;
    logic [c_EMPTY_W-1:0] empty;
    logic sop;
    logic eop;
    logic valid;
    if (!mon_on)
      return;
    for (ch = 0; ch < g_NUM_INPUTS; ch++) begin
      // Constant index. A variable read of these unpacked outputs is zero.
      if (ch == 0) begin
        data  = src_data_o[0];
        empty = src_empty_o[0];
        sop   = src_sop_o[0];
        eop   = src_eop_o[0];
        valid = src_valid_o[0];
      end else if (ch == 1) begin
        data  = src_data_o[1];
        empty = src_empty_o[1];
        sop   = src_sop_o[1];
        eop   = src_eop_o[1];
        valid = src_valid_o[1];
      end else begin
        data  = src_data_o[2];
        empty = src_empty_o[2];
        sop   = src_sop_o[2];
        eop   = src_eop_o[2];
        valid = src_valid_o[2];
      end
      if (!(valid && src_ready_i[ch]))
        continue;
      if (eop && int'(empty) >= c_WORD_B)
        $fatal(1, "loopback empty %0d ch %0d", empty, ch);
      n_valid = eop ? (c_WORD_B - int'(empty)) : c_WORD_B;
      if (got_n[ch] == 0 && !sop)
        $fatal(1, "loopback ch %0d missing sop words=%0d", ch, g_INTERLEAVE_WORDS);
      for (bi = 0; bi < n_valid; bi++) begin
        gbyte = 8'(be_get(256'(data), bi, 8, c_WORD_B));
        if (gbyte != exp_mem[ch][exp_rd[ch] + got_n[ch]])
          $fatal(1, "loopback ch %0d byte %0d got %02x exp %02x data %h words=%0d",
                 ch, got_n[ch], gbyte, exp_mem[ch][exp_rd[ch] + got_n[ch]],
                 data, g_INTERLEAVE_WORDS);
        got_n[ch]++;
      end
      if (eop) begin
        if (exp_len_rd[ch] == exp_len_wr[ch])
          $fatal(1, "loopback ch %0d extra eop", ch);
        elen = exp_len_mem[ch][exp_len_rd[ch]];
        if (got_n[ch] != int'(elen))
          $fatal(1, "loopback ch %0d len got %0d exp %0d", ch, got_n[ch], elen);
        exp_rd[ch] += int'(elen);
        exp_len_rd[ch]++;
        got_n[ch] = 0;
      end
    end
  endtask

  task automatic drive();
    int ch;
    int n;
    int bi;
    int remain;
    logic [c_DATA_W-1:0] word;
    for (ch = 0; ch < g_NUM_INPUTS; ch++) begin
      if (acc[ch]) begin
        acc[ch]  = 1'b0;
        beat[ch] = 1'b0;
        n = c_WORD_B - int'(snk_empty_i[ch]);
        tx_pos[ch] += n;
        tx_left[ch] -= n;
        tx_rd[ch] += n;
        if (tx_left[ch] == 0 && tx_len_rd[ch] != tx_len_wr[ch])
          tx_len_rd[ch]++;
      end
      if (!beat[ch] && tx_wr[ch] != tx_rd[ch] && (tx_left[ch] != 0 || tx_len_rd[ch] != tx_len_wr[ch])) begin
        if (tx_left[ch] == 0) begin
          tx_left[ch] = tx_len_mem[ch][tx_len_rd[ch]];
          tx_pos[ch]  = 0;
        end
        remain = tx_left[ch];
        n = remain;
        if (n > c_WORD_B)
          n = c_WORD_B;
        word = '0;
        snk_valid_i[ch] = 1'b1;
        snk_sop_i[ch]   = (tx_pos[ch] == 0);
        snk_eop_i[ch]   = (n == remain);
        snk_empty_i[ch] = c_EMPTY_W'(c_WORD_B - n);
        for (bi = 0; bi < n; bi++)
          word = c_DATA_W'(be_put(256'(word), 32'(tx_mem[ch][tx_rd[ch] + bi]), bi, 8, c_WORD_B));
        if (ch == 0) begin
          snk_data_i[0] = word;
          snk_data_p[0 +: c_DATA_W] = word;
          snk_empty_p[0 +: c_EMPTY_W] = snk_empty_i[0];
        end else if (ch == 1) begin
          snk_data_i[1] = word;
          snk_data_p[c_DATA_W +: c_DATA_W] = word;
          snk_empty_p[c_EMPTY_W +: c_EMPTY_W] = snk_empty_i[1];
        end else begin
          snk_data_i[2] = word;
          snk_data_p[2*c_DATA_W +: c_DATA_W] = word;
          snk_empty_p[2*c_EMPTY_W +: c_EMPTY_W] = snk_empty_i[2];
        end
        beat[ch] = 1'b1;
      end else if (!beat[ch]) begin
        snk_valid_i[ch] = 1'b0;
        snk_sop_i[ch]   = 1'b1;
        snk_eop_i[ch]   = 1'b0;
        snk_empty_i[ch] = '0;
      end
    end
  endtask

  initial begin : proc_run
    int ch;
    int sz;
    int rep;
    done_o = 1'b0;
    mon_on = 1'b0;
    src_ready_i = '1;
    for (ch = 0; ch < g_NUM_INPUTS; ch++) begin
      snk_sop_i[ch]   = 1'b1;
      snk_eop_i[ch]   = 1'b0;
      snk_valid_i[ch] = 1'b0;
      snk_data_i[ch]  = '0;
      snk_empty_i[ch] = '0;
      beat[ch]        = 1'b0;
      acc[ch]         = 1'b0;
      tx_pos[ch]      = 0;
      tx_left[ch]     = 0;
      tx_rd[ch]       = 0;
      tx_wr[ch]       = 0;
      exp_rd[ch]      = 0;
      exp_wr[ch]      = 0;
      tx_len_rd[ch]   = 0;
      tx_len_wr[ch]   = 0;
      exp_len_rd[ch]  = 0;
      exp_len_wr[ch]  = 0;
      got_n[ch]       = 0;
    end
    seed_rand(g_SEED);
    for (ch = 0; ch < g_NUM_INPUTS; ch++)
      enqueue(ch, g_PACKET_SIZE);
    for (ch = 0; ch < g_NUM_INPUTS; ch++)
      for (sz = 1; sz <= g_PACKET_SIZE; sz++)
        for (rep = 0; rep < g_N_PACKETS; rep++)
          enqueue(ch, sz);
    @(posedge clk_i);
    wait (reset_i == 1'b0);
    @(posedge clk_i);
    mon_on = 1'b1;
    while (!tx_idle()) begin
      @(negedge clk_i);
      drive();
      @(posedge clk_i);
      for (ch = 0; ch < g_NUM_INPUTS; ch++)
        acc[ch] = beat[ch] && snk_valid_i[ch] && snk_ready_o[ch];
      sample();
    end
    repeat (6) begin
      @(posedge clk_i);
      sample();
    end
    done_o = 1'b1;
  end

endmodule

module interleaver_loopback_tb;
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic done_words;
  logic done_pkt;

  always #5 clk = ~clk;

  initial begin
    reset = 1'b1;
    @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
  end

  initial begin
    #50ms;
    $fatal(1, "interleaver_loopback_tb watchdog");
  end

  interleaver_loopback_case #(
    .g_INTERLEAVE_WORDS (1'b1),
    .g_SEED             (32'h10CB_0001)
  ) u_words (
    .clk_i   (clk),
    .reset_i (reset),
    .done_o  (done_words)
  );

  interleaver_loopback_case #(
    .g_INTERLEAVE_WORDS (1'b0),
    .g_SEED             (32'h10CB_0002)
  ) u_packets (
    .clk_i   (clk),
    .reset_i (reset),
    .done_o  (done_pkt)
  );

  initial begin
    wait (done_words && done_pkt);
    $display("PASS interleaver_loopback_tb");
    $finish;
  end
endmodule
