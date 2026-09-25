// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// SVA for rle_encode, translated from fv/endec/rle_encode.psl.
// Multi-cycle PSL sequences are the same checks written with a one-cycle
// implication and explicit history.

`timescale 1ns/1ps

module rle_encode_sva #(
  parameter int unsigned g_WORD_WIDTH  = 16,
  parameter int unsigned g_COUNT_WIDTH = 3
) (
  input logic                                  clk_i,
  input logic                                  reset_i,
  input logic                                  flush_i,
  input logic                                  snk_ready_o,
  input logic                                  snk_valid_i,
  input logic [g_WORD_WIDTH-1:0]               snk_data_i,
  input logic                                  src_ready_i,
  input logic                                  src_valid_o,
  input logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0] src_data_o,
  // VHDL signal rreg.ready
  input logic                                  rreg_ready
);

  localparam int unsigned c_WORD_MAX = (2 ** g_COUNT_WIDTH) - 1;

  logic [g_COUNT_WIDTH-1:0] s_count = '0;
  logic [g_WORD_WIDTH-1:0]  s_word  = '0;
  // First clock only: PSL `assume {reset_i}`.
  logic                     s_start = 1'b1;

  // History for {not flush; flush && ... && prev(s_count) != 0} |=> ...
  logic                     s_prev_not_flush = 1'b0;
  logic [g_COUNT_WIDTH-1:0] s_count_d       = '0;
  logic [g_WORD_WIDTH-1:0]  s_word_d        = '0;

  // History for the consecutive-flush sequence.
  logic       s_armed    = 1'b0;
  logic [5:0] s_flush_cnt = '0;
  logic       s_prev_b   = 1'b0;

  wire s_b_cycle = flush_i && (!src_valid_o || (src_valid_o && src_ready_i));
  // Antecedent completes on the last cycle of the PSL sequence.
  wire s_double_ante = s_armed && flush_i && src_ready_i && s_prev_b && (s_flush_cnt >= 6'd2);

  always_ff @(posedge clk_i) begin : proc_shadow
    if (reset_i) begin
      s_count <= '0;
      s_word  <= '0;
    end else begin
      if (snk_valid_i && snk_ready_o) begin
        s_word <= snk_data_i;
        if ((snk_data_i != s_word) || (s_count == g_COUNT_WIDTH'(c_WORD_MAX)))
          s_count <= g_COUNT_WIDTH'(1);
        else
          s_count <= s_count + g_COUNT_WIDTH'(1);
      end
      if (flush_i) begin
        s_count <= '0;
        s_word  <= '0;
      end
    end
  end

  always_ff @(posedge clk_i) begin : proc_hist
    s_start          <= 1'b0;
    s_prev_not_flush <= !flush_i;
    s_count_d        <= s_count;
    s_word_d         <= s_word;
    if (reset_i) begin
      s_armed     <= 1'b0;
      s_flush_cnt <= '0;
      s_prev_b    <= 1'b0;
    end else begin
      s_prev_b <= s_b_cycle;
      if (flush_i && s_armed) begin
        if (s_flush_cnt != 6'h3f)
          s_flush_cnt <= s_flush_cnt + 6'd1;
      end else if (!flush_i) begin
        s_flush_cnt <= '0;
      end
      if (!flush_i && !snk_valid_i)
        s_armed <= 1'b1;
      else if (!flush_i)
        s_armed <= 1'b0;
    end
  end

  assume_init_reset: assume property (@(posedge clk_i) s_start |-> reset_i);

  assume_stable_in: assume property (@(posedge clk_i)
    (snk_valid_i && !snk_ready_o) |=> (snk_valid_i && (snk_data_i == $past(snk_data_i))));

  if (g_WORD_WIDTH >= 5) begin : gen_assume_narrow
    // PSL: snk_data_i(left downto 4) == 0. Null when the word is narrower than 5.
    assume_narrow: assume property (@(posedge clk_i)
      snk_data_i[g_WORD_WIDTH-1:4] == '0);
  end

  t_no_valid_after_reset: assert property (@(posedge clk_i)
    reset_i |=> (src_valid_o == 1'b0));

  t_out_stable_backpressure: assert property (@(posedge clk_i) disable iff (reset_i)
    (src_valid_o && !src_ready_i) |=> (src_valid_o && (src_data_o == $past(src_data_o))));

  t_rle_out_normal: assert property (@(posedge clk_i) disable iff (reset_i || flush_i)
    (snk_valid_i && snk_ready_o && src_ready_i && (snk_data_i != s_word) && (s_count != '0))
    |=> (src_valid_o && (src_data_o[g_WORD_WIDTH-1:0] == $past(s_word))
         && (src_data_o[g_WORD_WIDTH +: g_COUNT_WIDTH] == $past(s_count))));

  t_rle_out_ovf: assert property (@(posedge clk_i) disable iff (reset_i || flush_i)
    (snk_valid_i && snk_ready_o && src_ready_i && (snk_data_i != s_word)
     && (s_count == g_COUNT_WIDTH'(c_WORD_MAX)))
    |=> (src_valid_o && (src_data_o[g_WORD_WIDTH-1:0] == $past(s_word))
         && (src_data_o[g_WORD_WIDTH +: g_COUNT_WIDTH] == g_COUNT_WIDTH'(c_WORD_MAX))));

  t_rle_flush_empty: assert property (@(posedge clk_i) disable iff (reset_i || snk_valid_i)
    (flush_i && src_ready_i && !src_valid_o && (s_count != '0))
    |=> (src_valid_o && (src_data_o[g_WORD_WIDTH-1:0] == $past(s_word))));

  t_rle_flush_buffered_no_in: assert property (@(posedge clk_i) disable iff (reset_i || snk_valid_i)
    (flush_i && src_ready_i && src_valid_o && rreg_ready && (s_count != '0))
    |=> (src_valid_o && (src_data_o[g_WORD_WIDTH-1:0] == $past(s_word))));

  // {!flush; flush && ready && !valid && prev(count) != 0} |=> data == prev(prev(word))
  t_rle_flush_buffered_no_skid: assert property (@(posedge clk_i) disable iff (reset_i || snk_valid_i)
    (s_prev_not_flush && flush_i && src_ready_i && !src_valid_o && (s_count_d != '0))
    |=> (src_valid_o && (src_data_o[g_WORD_WIDTH-1:0] == $past(s_word_d))));

  // Consecutive flush, after the buffered word has been taken, leaves valid low.
  t_double_flush: assert property (@(posedge clk_i) disable iff (reset_i)
    s_double_ante |=> !src_valid_o);

endmodule

bind rle_encode rle_encode_sva #(
  .g_WORD_WIDTH  (g_WORD_WIDTH),
  .g_COUNT_WIDTH (g_COUNT_WIDTH)
) rle_encode_sva_i (
  .clk_i       (clk_i),
  .reset_i     (reset_i),
  .flush_i     (flush_i),
  .snk_ready_o (snk_ready_o),
  .snk_valid_i (snk_valid_i),
  .snk_data_i  (snk_data_i),
  .src_ready_i (src_ready_i),
  .src_valid_o (src_valid_o),
  .src_data_o  (src_data_o),
  .rreg_ready  (rreg.ready)
);
