// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Joins 1024 symbols, twice. The second pass applies random backpressure on
// the output, matching packet_join_tb. Symbol width and symbols per beat
// follow the configurations in sim/packet/run.py.

`timescale 1ns/1ps

import packet_tb_pkg::*;

module packet_join_case #(
  parameter int unsigned g_SYM_WIDTH = 8,
  parameter int unsigned g_DATA_SYM  = 4,
  parameter int unsigned g_SEED      = 8
) (
  input  logic clk_i,
  input  logic reset_i,
  output logic done_o
);

  localparam int c_NUM_SYM  = 1024;
  localparam int c_MAX_IN   = (c_NUM_SYM + 31) / 32;
  localparam int c_DATA_W   = int'(g_DATA_SYM) * int'(g_SYM_WIDTH);
  localparam int c_EMPTY_W  = colibri_types::avst_empty_width(c_DATA_W, int'(g_SYM_WIDTH));

  logic                  last_i;
  logic [c_DATA_W-1:0]   snk_data_i;
  logic [c_EMPTY_W-1:0]  snk_empty_i;
  logic                  snk_sop_i, snk_eop_i, snk_valid_i, snk_ready_o;
  logic [c_DATA_W-1:0]   src_data_o;
  logic [c_EMPTY_W-1:0]  src_empty_o;
  logic                  src_sop_o, src_eop_o, src_valid_o, src_ready_i;

  logic [31:0] syms [0:c_NUM_SYM-1];
  // Fixed memory. A queue loses entries under this simulator.
  int          lens_mem [0:c_NUM_SYM-1];
  int          lens_n;
  int          pkt;
  int          pkt_pos;
  int          in_base;
  int          out_idx;
  bit          beat;
  bit          acc;
  bit          saw_sop;
  int          bp_phase;
  int          guard;

  packet_join #(
    .g_SYM_WIDTH (g_SYM_WIDTH),
    .g_DATA_SYM  (g_DATA_SYM)
  ) u_dut (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .last_i      (last_i),
    .snk_data_i  (snk_data_i),
    .snk_empty_i (snk_empty_i),
    .snk_sop_i   (snk_sop_i),
    .snk_eop_i   (snk_eop_i),
    .snk_valid_i (snk_valid_i),
    .snk_ready_o (snk_ready_o),
    .src_data_o  (src_data_o),
    .src_empty_o (src_empty_o),
    .src_sop_o   (src_sop_o),
    .src_eop_o   (src_eop_o),
    .src_valid_o (src_valid_o),
    .src_ready_i (src_ready_i)
  );

  function automatic logic [31:0] sym_mask();
    if (g_SYM_WIDTH >= 32)
      return 32'hffff_ffff;
    return (32'b1 << g_SYM_WIDTH) - 1;
  endfunction

  task automatic build_lens();
    int rem;
    int n;
    lens_n = 0;
    rem = c_NUM_SYM;
    while (rem > c_MAX_IN) begin
      n = urand(1, c_MAX_IN);
      lens_mem[lens_n] = n;
      lens_n++;
      rem -= n;
    end
    lens_mem[lens_n] = rem;
    lens_n++;
  endtask

  task automatic sample();
    int n_valid;
    int s;
    logic [31:0] got;
    if (!(src_valid_o && src_ready_i))
      return;
    if (bp_phase == 0 && src_eop_o)
      bp_phase = 1;
    else if (bp_phase == 1 && src_sop_o)
      bp_phase = 2;
    else if (bp_phase == 2 && src_eop_o)
      bp_phase = 3;
    if (int'(src_empty_o) > g_DATA_SYM)
      $fatal(1, "packet_join sym=%0d data=%0d empty %0d", g_SYM_WIDTH, g_DATA_SYM, src_empty_o);
    n_valid = int'(g_DATA_SYM) - int'(src_empty_o);
    if (!saw_sop) begin
      if (!src_sop_o)
        $fatal(1, "packet_join sym=%0d data=%0d missing sop", g_SYM_WIDTH, g_DATA_SYM);
      saw_sop = 1'b1;
    end else if (src_sop_o) begin
      $fatal(1, "packet_join sym=%0d data=%0d extra sop", g_SYM_WIDTH, g_DATA_SYM);
    end
    for (s = 0; s < n_valid; s++) begin
      if (out_idx >= c_NUM_SYM)
        $fatal(1, "packet_join sym=%0d data=%0d too many symbols", g_SYM_WIDTH, g_DATA_SYM);
      got = be_get(256'(src_data_o), s, int'(g_SYM_WIDTH), int'(g_DATA_SYM));
      if (got != syms[out_idx])
        $fatal(1, "packet_join sym=%0d data=%0d idx %0d got %0h exp %0h",
               g_SYM_WIDTH, g_DATA_SYM, out_idx, got, syms[out_idx]);
      out_idx++;
    end
    if (src_eop_o && out_idx != c_NUM_SYM)
      $fatal(1, "packet_join sym=%0d data=%0d early eop at %0d n_valid %0d in_base %0d pkt %0d/%0d empty %0d",
             g_SYM_WIDTH, g_DATA_SYM, out_idx, n_valid, in_base, pkt, lens_n, src_empty_o);
    if (out_idx == c_NUM_SYM && !src_eop_o)
      $fatal(1, "packet_join sym=%0d data=%0d missing eop", g_SYM_WIDTH, g_DATA_SYM);
  endtask

  task automatic drive();
    int n;
    int s;
    int remain;
    if (acc) begin
      acc  = 1'b0;
      beat = 1'b0;
      n = int'(g_DATA_SYM) - int'(snk_empty_i);
      pkt_pos += n;
      in_base += n;
      if (pkt_pos >= lens_mem[pkt]) begin
        pkt++;
        pkt_pos = 0;
        if (pkt >= lens_n)
          last_i = 1'b0;
      end
    end
    if (!beat && pkt < lens_n) begin
      remain = lens_mem[pkt] - pkt_pos;
      n = remain;
      if (n > g_DATA_SYM)
        n = g_DATA_SYM;
      if (pkt == lens_n - 1)
        last_i = 1'b1;
      snk_data_i  = '0;
      snk_valid_i = 1'b1;
      snk_sop_i   = (pkt_pos == 0);
      snk_eop_i   = (n == remain);
      snk_empty_i = c_EMPTY_W'(int'(g_DATA_SYM) - n);
      for (s = 0; s < n; s++)
        snk_data_i = c_DATA_W'(be_put(256'(snk_data_i), syms[in_base + s], s, int'(g_SYM_WIDTH), int'(g_DATA_SYM)));
      beat = 1'b1;
    end else if (!beat) begin
      snk_valid_i = 1'b0;
      snk_sop_i   = 1'b0;
      snk_eop_i   = 1'b0;
      snk_empty_i = '0;
    end
  endtask

  initial begin : proc_run
    int i;
    int pass;
    done_o      = 1'b0;
    last_i      = 1'b0;
    snk_sop_i   = 1'b0;
    snk_eop_i   = 1'b0;
    snk_valid_i = 1'b0;
    snk_data_i  = '0;
    snk_empty_i = '0;
    src_ready_i = 1'b1;
    beat        = 1'b0;
    acc         = 1'b0;
    bp_phase    = 0;
    seed_rand(g_SEED);
    for (i = 0; i < c_NUM_SYM; i++)
      syms[i] = $urandom & sym_mask();
    @(posedge clk_i);
    wait (reset_i == 1'b0);
    repeat (2) @(posedge clk_i);
    for (pass = 0; pass < 2; pass++) begin
      build_lens();
      pkt     = 0;
      pkt_pos = 0;
      in_base = 0;
      out_idx = 0;
      saw_sop = 1'b0;
      beat    = 1'b0;
      acc     = 1'b0;
      guard   = 0;
      while (out_idx < c_NUM_SYM) begin
        @(negedge clk_i);
        if (bp_phase == 2)
          src_ready_i = 1'($urandom_range(1, 0));
        else
          src_ready_i = 1'b1;
        drive();
        @(posedge clk_i);
        acc = beat && snk_valid_i && snk_ready_o;
        sample();
        guard++;
        if (guard > 200000)
          $fatal(1, "packet_join sym=%0d data=%0d stalled pass %0d", g_SYM_WIDTH, g_DATA_SYM, pass);
      end
      repeat (10) @(posedge clk_i);
    end
    done_o = 1'b1;
  end

endmodule

module packet_join_tb;
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
    #50ms;
    $fatal(1, "packet_join_tb watchdog");
  end

  packet_join_case #(.g_SYM_WIDTH(1), .g_DATA_SYM(1),  .g_SEED(8))   u0 (.clk_i(clk), .reset_i(reset), .done_o(done[0]));
  packet_join_case #(.g_SYM_WIDTH(1), .g_DATA_SYM(4),  .g_SEED(9))   u1 (.clk_i(clk), .reset_i(reset), .done_o(done[1]));
  packet_join_case #(.g_SYM_WIDTH(1), .g_DATA_SYM(17), .g_SEED(10))  u2 (.clk_i(clk), .reset_i(reset), .done_o(done[2]));
  packet_join_case #(.g_SYM_WIDTH(8), .g_DATA_SYM(1),  .g_SEED(11))  u3 (.clk_i(clk), .reset_i(reset), .done_o(done[3]));
  packet_join_case #(.g_SYM_WIDTH(8), .g_DATA_SYM(4),  .g_SEED(12))  u4 (.clk_i(clk), .reset_i(reset), .done_o(done[4]));
  packet_join_case #(.g_SYM_WIDTH(8), .g_DATA_SYM(17), .g_SEED(13))  u5 (.clk_i(clk), .reset_i(reset), .done_o(done[5]));
  packet_join_case #(.g_SYM_WIDTH(9), .g_DATA_SYM(1),  .g_SEED(14))  u6 (.clk_i(clk), .reset_i(reset), .done_o(done[6]));
  packet_join_case #(.g_SYM_WIDTH(9), .g_DATA_SYM(4),  .g_SEED(15))  u7 (.clk_i(clk), .reset_i(reset), .done_o(done[7]));
  packet_join_case #(.g_SYM_WIDTH(9), .g_DATA_SYM(17), .g_SEED(16))  u8 (.clk_i(clk), .reset_i(reset), .done_o(done[8]));

  initial begin
    wait (&done);
    $display("PASS packet_join_tb");
    $finish;
  end
endmodule
