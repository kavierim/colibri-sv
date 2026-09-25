// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Concurrent assertions translated from fv/memory/fifo.psl.
// The original PSL line is commented above each property.

`timescale 1ns/1ps

// verilator lint_off UNUSEDPARAM
module fifo_sva #(
  parameter int g_NUM_WORDS    = 4,
  parameter int g_INPUT_WIDTH  = 8,
  parameter int g_OUTPUT_WIDTH = 8,
  parameter bit g_ENABLE_FWFT  = 1'b0
) (
  input logic clk_i,
  input logic reset_i,
  input logic wrreq_i,
  input logic rdreq_i,
  input logic empty_o,
  input logic full_o,
  input logic [colibri_utils::log2ceil(g_NUM_WORDS):0] usedw_o,
  input int wr_ptr,
  input int rd_ptr
);

  localparam int c_USEDW_W = colibri_utils::log2ceil(g_NUM_WORDS) + 1;

  int unsigned cyc;
  initial cyc = 0;
  always_ff @(posedge clk_i) cyc <= cyc + 1;

  // PSL: assume {reset_i; not reset_i};
  assume property (@(posedge clk_i) (cyc == 0) |-> reset_i);
  assume property (@(posedge clk_i) (cyc == 1) |-> !reset_i);

  // PSL: assume always (not reset_i) |=> (not reset_i);
  assume property (@(posedge clk_i) !reset_i |=> !reset_i);

  // PSL: assume always (reset_i) -> (not wrreq_i and not rdreq_i);
  assume property (@(posedge clk_i) reset_i |-> !wrreq_i && !rdreq_i);

  // PSL: t_after_reset_empty : assert always (reset_i) |=> (empty_o);
  assert property (@(posedge clk_i) reset_i |=> empty_o);

  // PSL: t_after_reset_n_full : assert always (reset_i) |=> (not full_o);
  assert property (@(posedge clk_i) reset_i |=> !full_o);

  // PSL: t_after_reset_usedw : assert always (reset_i) |=> (usedw_o = (usedw_o'range => '0'));
  assert property (@(posedge clk_i) reset_i |=> (usedw_o == '0));

  // PSL: t_usedw_empty: assert always (usedw_o = (usedw_o'range => '0')) |-> (empty_o);
  assert property (@(posedge clk_i) (usedw_o == '0) |-> empty_o);

  // PSL: t_usedw_full: assert always (usedw_o = (usedw_o'range => to_unsigned(g_NUM_WORDS,usedw_o'length))) |-> (full_o);
  assert property (@(posedge clk_i) (usedw_o == c_USEDW_W'(g_NUM_WORDS)) |-> full_o);

  // PSL: t_wr_no_rd_normal : assert always (wrreq_i and not rdreq_i and not full_o) |=> (usedw_o = prev(usedw_o) + 1);
  assert property (@(posedge clk_i)
    (wrreq_i && !rdreq_i && !full_o) |=> (usedw_o == ($past(usedw_o) + c_USEDW_W'(1))));

  // PSL: t_no_wr_rd_normal : assert always (not wrreq_i and rdreq_i and not empty_o) |=> (usedw_o = prev(usedw_o) - 1);
  assert property (@(posedge clk_i)
    (!wrreq_i && rdreq_i && !empty_o) |=> (usedw_o == ($past(usedw_o) - c_USEDW_W'(1))));

  // PSL: t_wr_rd_normal : assert always (wrreq_i and rdreq_i and not full_o and not empty_o) |=> (usedw_o = prev(usedw_o));
  assert property (@(posedge clk_i)
    (wrreq_i && rdreq_i && !full_o && !empty_o) |=> (usedw_o == $past(usedw_o)));

  // PSL: t_wr_on_full : assert always (wrreq_i and full_o) |=> (wr_ptr = prev(wr_ptr));
  assert property (@(posedge clk_i) (wrreq_i && full_o) |=> (wr_ptr == $past(wr_ptr)));

  // PSL: t_rd_on_empty : assert always (rdreq_i and empty_o) |=> (rd_ptr = prev(rd_ptr));
  assert property (@(posedge clk_i) (rdreq_i && empty_o) |=> (rd_ptr == $past(rd_ptr)));

endmodule
// verilator lint_on UNUSEDPARAM

bind fifo fifo_sva #(
  .g_NUM_WORDS(g_NUM_WORDS),
  .g_INPUT_WIDTH(g_INPUT_WIDTH),
  .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH),
  .g_ENABLE_FWFT(g_ENABLE_FWFT)
) fifo_sva_i (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .wrreq_i(wrreq_i),
  .rdreq_i(rdreq_i),
  .empty_o(empty_o),
  .full_o(full_o),
  .usedw_o(usedw_o),
  .wr_ptr(wr_ptr),
  .rd_ptr(rd_ptr)
);
