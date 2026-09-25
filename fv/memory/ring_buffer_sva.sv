// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Concurrent assertions translated from fv/memory/ring_buffer.psl.
// The original PSL line is commented above each property.
// `abort reset_i` is `disable iff (reset_i)`.
// Strong eventually is bounded here because this checker only uses supported operators.

`timescale 1ns/1ps

module ring_buffer_sva #(
  parameter int g_NUM_WORDS  = 4,
  parameter int g_DATA_WIDTH = 8
) (
  input logic clk_i,
  input logic reset_i,
  input logic snk_valid_i,
  input logic src_ready_i,
  input logic src_valid_o,
  input logic [g_DATA_WIDTH-1:0] src_data_o,
  input int usedw
);

  int unsigned cyc;
  initial cyc = 0;
  always_ff @(posedge clk_i) cyc <= cyc + 1;

  // PSL: assume {reset_i};
  assume property (@(posedge clk_i) (cyc == 0) |-> reset_i);

  // PSL: property p_reset_state is always {reset_i} |=> {src_valid_o = '0' and rreg.usedw = 0};
  assert property (@(posedge clk_i) reset_i |=> (src_valid_o == 1'b0 && usedw == 0));

  // PSL: property p_count_max is always ({rreg.usedw <= g_NUM_WORDS}) abort reset_i;
  assert property (@(posedge clk_i) disable iff (reset_i) usedw <= g_NUM_WORDS);

  // PSL: property p_overwrite_full is always ({snk_valid_i = '1' and (rreg.usedw = g_NUM_WORDS) and src_ready_i = '0'} |=> {rreg.usedw = g_NUM_WORDS}) abort reset_i;
  assert property (@(posedge clk_i) disable iff (reset_i)
    (snk_valid_i && (usedw == g_NUM_WORDS) && !src_ready_i) |=> (usedw == g_NUM_WORDS));

  // PSL: property p_empty_read is always ({rreg.usedw = 0} |-> {src_valid_o = '0'}) abort reset_i;
  assert property (@(posedge clk_i) disable iff (reset_i) (usedw == 0) |-> !src_valid_o);

  // PSL: property p_data_stable_norm is always ({src_valid_o = '1' and src_ready_i = '0' and rreg.usedw < g_NUM_WORDS} |=> {stable(src_data_o) and src_valid_o = '1'}) abort reset_i;
  assert property (@(posedge clk_i) disable iff (reset_i)
    (src_valid_o && !src_ready_i && (usedw < g_NUM_WORDS)) |=> ($stable(src_data_o) && src_valid_o));

  // PSL: property p_data_availability is always ({snk_valid_i = '1' and rreg.usedw < g_NUM_WORDS} |-> eventually! {src_valid_o}) abort reset_i;
  // Bounded stand-in for eventually!: a non-full write is visible on
  // src_valid_o in this cycle or the next.
  assert property (@(posedge clk_i) disable iff (reset_i)
    (snk_valid_i && (usedw < g_NUM_WORDS) && !src_valid_o) |=> src_valid_o);

  // PSL: c_full_rw : cover {snk_valid_i = '1' and src_ready_i = '1' and src_valid_o = '1' and (rreg.usedw = g_NUM_WORDS)};
  cover property (@(posedge clk_i)
    snk_valid_i && src_ready_i && src_valid_o && (usedw == g_NUM_WORDS));

  // PSL: c_full_write : cover {snk_valid_i = '1' and src_ready_i = '0' and (rreg.usedw = g_NUM_WORDS)};
  cover property (@(posedge clk_i)
    snk_valid_i && !src_ready_i && (usedw == g_NUM_WORDS));

  // PSL: c_read_only : cover {snk_valid_i = '0' and src_ready_i = '1' and src_valid_o = '1'};
  cover property (@(posedge clk_i)
    !snk_valid_i && src_ready_i && src_valid_o);

endmodule

bind ring_buffer ring_buffer_sva #(
  .g_NUM_WORDS(g_NUM_WORDS),
  .g_DATA_WIDTH(g_DATA_WIDTH)
) ring_buffer_sva_i (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .snk_valid_i(snk_valid_i),
  .src_ready_i(src_ready_i),
  .src_valid_o(src_valid_o),
  .src_data_o(src_data_o),
  .usedw(rreg.usedw)
);
