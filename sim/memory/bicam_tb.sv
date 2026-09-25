// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/bicam_tb.vhdl.
// Writes unique keys, searches hits and a miss, clears every entry, and
// tries a write while full.

`timescale 1ns/1ps

module bicam_tb;

  localparam int c_N_WORDS    = 8;
  localparam int c_DATA_WIDTH = 8;
  localparam int c_ADDR_W     = colibri_utils::downto_width(colibri_utils::log2ceil(c_N_WORDS));

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic rdreq = 1'b0;
  logic wrreq = 1'b0;
  logic clear = 1'b0;
  logic [c_DATA_WIDTH-1:0] data = '0;
  logic full;
  logic busy;
  logic match;
  logic [c_ADDR_W-1:0] addr;

  always #2.5 clk = ~clk;

  bicam #(
    .g_N_WORDS(c_N_WORDS),
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) bicam_inst (
    .clk_i(clk),
    .reset_i(reset),
    .rdreq_i(rdreq),
    .wrreq_i(wrreq),
    .clear_i(clear),
    .data_i(data),
    .full_o(full),
    .busy_o(busy),
    .match_o(match),
    .addr_o(addr)
  );

  logic [c_DATA_WIDTH-1:0] keys [0:c_N_WORDS-1];
  logic [c_ADDR_W-1:0] locs [0:c_N_WORDS-1];
  int bin_wr, bin_clr, bin_hit, bin_miss, bin_full;

  task automatic tick();
    @(posedge clk);
    #1;
  endtask

  task automatic write_key(input int idx);
    @(negedge clk);
    wrreq = 1'b1;
    clear = 1'b0;
    rdreq = 1'b0;
    data  = keys[idx];
    tick();
    locs[idx] = addr;
    wrreq = 1'b0;
    bin_wr++;
    tick();
    if (busy)
      tick();
  endtask

  task automatic search_key(input logic [c_DATA_WIDTH-1:0] key, input logic exp_match, input logic [c_ADDR_W-1:0] exp_addr);
    @(negedge clk);
    while (busy)
      tick();
    rdreq = 1'b1;
    wrreq = 1'b0;
    clear = 1'b0;
    data  = key;
    tick();
    rdreq = 1'b0;
    if (match !== exp_match)
      $fatal(1, "bicam_tb: match %b exp %b for %h", match, exp_match, key);
    if (exp_match && (addr !== exp_addr))
      $fatal(1, "bicam_tb: addr %h exp %h for %h", addr, exp_addr, key);
    if (exp_match)
      bin_hit++;
    else
      bin_miss++;
  endtask

  task automatic clear_key(input int idx);
    @(negedge clk);
    wrreq = 1'b1;
    clear = 1'b1;
    rdreq = 1'b0;
    data  = keys[idx];
    tick();
    wrreq = 1'b0;
    clear = 1'b0;
    if (!match)
      $fatal(1, "bicam_tb: clear missed %h", keys[idx]);
    if (addr !== locs[idx])
      $fatal(1, "bicam_tb: clear addr %h exp %h", addr, locs[idx]);
    bin_clr++;
    tick();
  endtask

  initial begin
    bin_wr   = 0;
    bin_clr  = 0;
    bin_hit  = 0;
    bin_miss = 0;
    bin_full = 0;
    for (int i = 0; i < c_N_WORDS; i++)
      keys[i] = c_DATA_WIDTH'(32'h10 + i);
    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    tick();

    for (int i = 0; i < c_N_WORDS; i++)
      write_key(i);
    tick();
    if (!full)
      $fatal(1, "bicam_tb: expected full");

    for (int i = 0; i < c_N_WORDS; i++)
      search_key(keys[i], 1'b1, locs[i]);
    search_key(8'hA5, 1'b0, '0);

    @(negedge clk);
    wrreq = 1'b1;
    clear = 1'b0;
    data  = 8'h5A;
    tick();
    wrreq = 1'b0;
    bin_full++;
    search_key(8'h5A, 1'b0, '0);

    for (int i = 0; i < c_N_WORDS; i++)
      clear_key(i);
    search_key(keys[0], 1'b0, '0);

    for (int i = 0; i < 4; i++)
      search_key(c_DATA_WIDTH'($urandom_range(0, 7)), 1'b0, '0);

    if ((bin_wr < 1) || (bin_clr < c_N_WORDS) || (bin_hit < 1) || (bin_miss < 1) || (bin_full < 1))
      $fatal(1, "bicam_tb: coverage wr %0d clr %0d hit %0d miss %0d full %0d",
             bin_wr, bin_clr, bin_hit, bin_miss, bin_full);
    $display("PASS bicam_tb");
    $finish;
  end

  initial begin
    #100_000;
    $fatal(1, "bicam_tb: timeout");
  end

endmodule
