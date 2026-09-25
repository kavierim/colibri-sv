// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// header_random: a packet carries its header in the first bytes. The DUT
// returns that header on src_header_o at the output sop and the payload after it.

`timescale 1ns/1ps

import packet_tb_pkg::*;

module header_remove_case #(
  parameter int unsigned g_DATA_WIDTH   = 32,
  parameter int unsigned g_HEADER_BYTES = 14,
  parameter int unsigned g_N_PACKETS    = 20,
  parameter int unsigned g_PACKET_SIZE  = 9000,
  parameter int unsigned g_SEED         = 32'hB220_0001
) (
  input  logic clk_i,
  input  logic reset_i,
  output logic done_o
);

  localparam int c_DATA_W   = int'(g_DATA_WIDTH);
  localparam int c_EMPTY_W  = colibri_types::avst_empty_width(c_DATA_W, 8);
  localparam int c_WORD_B   = c_DATA_W / 8;
  localparam int c_HDR_BITS = int'(g_HEADER_BYTES) * 8;
  localparam int c_MIN_BYTES = int'(g_HEADER_BYTES) + 1;
  localparam int c_MAX_BYTES = int'(g_PACKET_SIZE) + int'(g_HEADER_BYTES);

  logic                    snk_sop_i;
  logic                    snk_eop_i;
  logic                    snk_valid_i;
  logic                    snk_ready_o;
  logic [c_DATA_W-1:0]     snk_data_i;
  logic [c_EMPTY_W-1:0]    snk_empty_i;
  logic                    src_sop_o;
  logic                    src_eop_o;
  logic                    src_valid_o;
  logic                    src_ready_i;
  logic [c_DATA_W-1:0]     src_data_o;
  logic [c_EMPTY_W-1:0]    src_empty_o;
  logic [c_HDR_BITS-1:0]   src_header_o;

  logic [7:0] exp_bytes[$];
  logic [7:0] got_bytes[$];
  logic [7:0] got_header[$];
  bit         mon_on;
  bit         saw_eop;
  bit         saw_header;
  int         pkt_i;

  header_remove #(
    .g_HEADER_BYTES (g_HEADER_BYTES),
    .g_DATA_WIDTH   (g_DATA_WIDTH)
  ) u_dut (
    .clk_i        (clk_i),
    .reset_i      (reset_i),
    .snk_sop_i    (snk_sop_i),
    .snk_eop_i    (snk_eop_i),
    .snk_valid_i  (snk_valid_i),
    .snk_ready_o  (snk_ready_o),
    .snk_data_i   (snk_data_i),
    .snk_empty_i  (snk_empty_i),
    .src_sop_o    (src_sop_o),
    .src_eop_o    (src_eop_o),
    .src_valid_o  (src_valid_o),
    .src_ready_i  (src_ready_i),
    .src_data_o   (src_data_o),
    .src_empty_o  (src_empty_o),
    .src_header_o (src_header_o)
  );

  function automatic int unsigned pick_len(input int unsigned index);
    int unsigned lo;
    int unsigned hi;
    if (index == 0)
      return c_MIN_BYTES;
    if (index == 1)
      return c_MAX_BYTES;
    lo = c_MIN_BYTES + (c_MAX_BYTES - c_MIN_BYTES) * index / g_N_PACKETS;
    hi = c_MIN_BYTES + (c_MAX_BYTES - c_MIN_BYTES) * (index + 1) / g_N_PACKETS;
    if (hi <= lo)
      hi = lo + 1;
    if (hi > c_MAX_BYTES)
      hi = c_MAX_BYTES;
    return urand(lo, hi);
  endfunction

  task automatic sample();
    int n_valid;
    int bi;
    if (!mon_on || !src_valid_o || !src_ready_i)
      return;
    if (src_sop_o) begin
      saw_header = 1'b1;
      got_header = {};
      for (bi = 0; bi < g_HEADER_BYTES; bi++)
        got_header.push_back(8'(be_get(256'(src_header_o), bi, 8, int'(g_HEADER_BYTES))));
      for (bi = 0; bi < g_HEADER_BYTES; bi++) begin
        if (got_header[bi] != exp_bytes[bi])
          $fatal(1, "header_remove w=%0d h=%0d pkt %0d header byte %0d got %02x exp %02x",
                 g_DATA_WIDTH, g_HEADER_BYTES, pkt_i, bi, got_header[bi], exp_bytes[bi]);
      end
    end
    // empty counts only on end of packet. Mid-packet beats are full words.
    if (src_eop_o && int'(src_empty_o) >= c_WORD_B)
      $fatal(1, "header_remove w=%0d h=%0d empty %0d", g_DATA_WIDTH, g_HEADER_BYTES, src_empty_o);
    n_valid = src_eop_o ? (c_WORD_B - int'(src_empty_o)) : c_WORD_B;
    if (got_bytes.size() == 0 && !src_sop_o)
      $fatal(1, "header_remove w=%0d h=%0d pkt %0d missing sop", g_DATA_WIDTH, g_HEADER_BYTES, pkt_i);
    for (bi = 0; bi < n_valid; bi++)
      got_bytes.push_back(8'(be_get(256'(src_data_o), bi, 8, c_WORD_B)));
    if (src_eop_o) begin
      if (!saw_header)
        $fatal(1, "header_remove w=%0d h=%0d pkt %0d header missing", g_DATA_WIDTH, g_HEADER_BYTES, pkt_i);
      if (got_bytes.size() != exp_bytes.size() - g_HEADER_BYTES)
        $fatal(1, "header_remove w=%0d h=%0d pkt %0d len got %0d exp %0d",
               g_DATA_WIDTH, g_HEADER_BYTES, pkt_i, got_bytes.size(),
               exp_bytes.size() - g_HEADER_BYTES);
      for (bi = 0; bi < got_bytes.size(); bi++) begin
        if (got_bytes[bi] != exp_bytes[g_HEADER_BYTES + bi])
          $fatal(1, "header_remove w=%0d h=%0d pkt %0d byte %0d got %02x exp %02x",
                 g_DATA_WIDTH, g_HEADER_BYTES, pkt_i, bi, got_bytes[bi],
                 exp_bytes[g_HEADER_BYTES + bi]);
      end
      saw_eop = 1'b1;
    end
  endtask

  task automatic clock();
    @(posedge clk_i);
    sample();
  endtask

  task automatic send_packet(input int unsigned nbytes);
    int unsigned idx;
    int unsigned n;
    int unsigned bi;
    int unsigned gap;
    idx = 0;
    while (idx < nbytes) begin
      n = nbytes - idx;
      if (n > c_WORD_B)
        n = c_WORD_B;
      @(negedge clk_i);
      snk_valid_i = 1'b1;
      snk_sop_i   = (idx == 0);
      snk_eop_i   = (idx + n == nbytes);
      snk_data_i  = '0;
      for (bi = 0; bi < n; bi++)
        snk_data_i = c_DATA_W'(be_put(256'(snk_data_i), 32'(exp_bytes[idx + bi]), int'(bi), 8, c_WORD_B));
      snk_empty_i = c_EMPTY_W'(c_WORD_B - n);
      do
        clock();
      while (!snk_ready_o);
      idx += n;
      gap = urand(0, 2);
      for (bi = 0; bi < gap; bi++) begin
        @(negedge clk_i);
        snk_valid_i = 1'b0;
        snk_eop_i   = 1'b0;
        snk_sop_i   = (idx == nbytes);
        clock();
      end
    end
    @(negedge clk_i);
    snk_valid_i = 1'b0;
    snk_eop_i   = 1'b0;
    snk_sop_i   = 1'b1;
  endtask

  initial begin
    done_o       = 1'b0;
    mon_on       = 1'b0;
    saw_eop      = 1'b0;
    saw_header   = 1'b0;
    snk_sop_i    = 1'b1;
    snk_eop_i    = 1'b0;
    snk_valid_i  = 1'b0;
    snk_data_i   = '0;
    snk_empty_i  = '0;
    src_ready_i  = 1'b1;
    seed_rand(g_SEED);
    @(posedge clk_i);
    wait (reset_i == 1'b0);
    @(posedge clk_i);
    mon_on = 1'b1;
    for (pkt_i = 0; pkt_i < g_N_PACKETS; pkt_i++) begin
      int unsigned nbytes;
      int unsigned bi;
      nbytes = pick_len(pkt_i);
      exp_bytes  = {};
      got_bytes  = {};
      got_header = {};
      saw_eop    = 1'b0;
      saw_header = 1'b0;
      for (bi = 0; bi < nbytes; bi++)
        exp_bytes.push_back(urand8());
      send_packet(nbytes);
      begin
        int spins;
        spins = 0;
        while (!saw_eop) begin
          clock();
          spins++;
          if (spins > 50000)
            $fatal(1, "header_remove w=%0d h=%0d pkt %0d no eop snk_ready %b src_valid %b",
                   g_DATA_WIDTH, g_HEADER_BYTES, pkt_i, snk_ready_o, src_valid_o);
        end
      end
    end
    repeat (4) clock();
    done_o = 1'b1;
  end

endmodule

module header_remove_tb;
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [8:0] done;

  always #5 clk = ~clk;

  initial begin
    reset = 1'b1;
    @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
  end

  initial begin
    #80ms;
    $fatal(1, "header_remove_tb watchdog");
  end

  header_remove_case #(.g_DATA_WIDTH(8),   .g_HEADER_BYTES(8),  .g_SEED(32'hB220_0001)) u0 (.clk_i(clk), .reset_i(reset), .done_o(done[0]));
  header_remove_case #(.g_DATA_WIDTH(8),   .g_HEADER_BYTES(14), .g_SEED(32'hB220_0002)) u1 (.clk_i(clk), .reset_i(reset), .done_o(done[1]));
  header_remove_case #(.g_DATA_WIDTH(8),   .g_HEADER_BYTES(20), .g_SEED(32'hB220_0003)) u2 (.clk_i(clk), .reset_i(reset), .done_o(done[2]));
  header_remove_case #(.g_DATA_WIDTH(64),  .g_HEADER_BYTES(8),  .g_SEED(32'hB220_0004)) u3 (.clk_i(clk), .reset_i(reset), .done_o(done[3]));
  header_remove_case #(.g_DATA_WIDTH(64),  .g_HEADER_BYTES(14), .g_SEED(32'hB220_0005)) u4 (.clk_i(clk), .reset_i(reset), .done_o(done[4]));
  header_remove_case #(.g_DATA_WIDTH(64),  .g_HEADER_BYTES(20), .g_SEED(32'hB220_0006)) u5 (.clk_i(clk), .reset_i(reset), .done_o(done[5]));
  header_remove_case #(.g_DATA_WIDTH(256), .g_HEADER_BYTES(8),  .g_SEED(32'hB220_0007)) u6 (.clk_i(clk), .reset_i(reset), .done_o(done[6]));
  header_remove_case #(.g_DATA_WIDTH(256), .g_HEADER_BYTES(14), .g_SEED(32'hB220_0008)) u7 (.clk_i(clk), .reset_i(reset), .done_o(done[7]));
  header_remove_case #(.g_DATA_WIDTH(256), .g_HEADER_BYTES(20), .g_SEED(32'hB220_0009)) u8 (.clk_i(clk), .reset_i(reset), .done_o(done[8]));

  initial begin
    wait (&done);
    $display("PASS header_remove_tb");
    $finish;
  end
endmodule
