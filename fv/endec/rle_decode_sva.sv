// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// SVA for rle_decode, translated from fv/endec/rle_decode.psl.
// The count sequence is a one-cycle implication over an explicit gap flag.

`timescale 1ns/1ps

module rle_decode_sva #(
  parameter int unsigned g_WORD_WIDTH  = 16,
  parameter int unsigned g_COUNT_WIDTH = 3
) (
  input logic                                  clk_i,
  input logic                                  reset_i,
  input logic                                  snk_ready_o,
  input logic                                  snk_valid_i,
  input logic [g_WORD_WIDTH+g_COUNT_WIDTH-1:0] snk_data_i,
  input logic                                  src_ready_i,
  input logic                                  src_valid_o,
  input logic [g_WORD_WIDTH-1:0]               src_data_o
);

  localparam int c_IN_W = g_WORD_WIDTH + g_COUNT_WIDTH;

  logic [g_COUNT_WIDTH-1:0] s_count     = '0;
  logic [g_WORD_WIDTH-1:0]  s_word      = '0;
  logic [g_WORD_WIDTH-1:0]  s_data_reg  = '0;
  int                       s_count_src = 0;
  int                       s_count_reg = 0;
  logic                     s_start     = 1'b1;
  // Saw snk_valid, then one or more cycles of !snk_valid.
  logic                     s_gap_ready = 1'b0;
  logic                     s_seen_valid = 1'b0;

  always_ff @(posedge clk_i) begin : proc_decode
    if (reset_i) begin
      s_count     <= '0;
      s_word      <= '0;
      s_data_reg  <= '0;
      s_count_reg <= 0;
      s_count_src <= 0;
    end else begin
      if (snk_valid_i && snk_ready_o) begin
        s_word  <= snk_data_i[g_WORD_WIDTH-1:0];
        s_count <= snk_data_i[g_WORD_WIDTH +: g_COUNT_WIDTH];
      end
      if (src_valid_o && src_ready_i) begin
        if (src_data_o != s_data_reg) begin
          s_count_src <= 1;
          s_count_reg <= int'(s_count);
        end else begin
          s_count_src <= s_count_src + 1;
        end
        s_data_reg <= src_data_o;
      end
    end
  end

  always_ff @(posedge clk_i) begin : proc_gap
    s_start <= 1'b0;
    // PSL aborts this sequence on reset or !src_ready.
    if (reset_i || !src_ready_i) begin
      s_gap_ready  <= 1'b0;
      s_seen_valid <= 1'b0;
    end else if (snk_valid_i) begin
      s_seen_valid <= 1'b1;
      s_gap_ready  <= 1'b0;
    end else if (s_seen_valid) begin
      s_gap_ready <= 1'b1;
    end
  end

  assume_init_reset: assume property (@(posedge clk_i) s_start |-> reset_i);

  assume_stable_in: assume property (@(posedge clk_i)
    (snk_valid_i && !snk_ready_o) |=> (snk_valid_i && (snk_data_i == $past(snk_data_i))));

  // Each accepted symbol's data byte differs from the previous one.
  assume_data_changes: assume property (@(posedge clk_i)
    snk_valid_i |-> (snk_data_i[g_WORD_WIDTH-1:0] != s_word));

  assume_count_nonzero: assume property (@(posedge clk_i)
    snk_data_i[g_WORD_WIDTH +: g_COUNT_WIDTH] != '0);

  if (c_IN_W >= 8) begin : gen_assume_narrow
    // PSL: snk_data_i(left-7 downto 0) == 0. Null on the 7-bit testbench port.
    assume_narrow: assume property (@(posedge clk_i)
      snk_data_i[c_IN_W-8:0] == '0);
  end

  t_no_valid_after_reset: assert property (@(posedge clk_i)
    reset_i |=> (src_valid_o == 1'b0));

  t_out_stable_backpressure: assert property (@(posedge clk_i) disable iff (reset_i)
    (src_valid_o && !src_ready_i) |=> (src_valid_o && (src_data_o == $past(src_data_o))));

  t_rle_forward: assert property (@(posedge clk_i) disable iff (reset_i)
    (snk_valid_i && snk_ready_o && src_ready_i && !src_valid_o)
    |=> (src_valid_o && (src_data_o == s_word)));

  // {snk_valid; (!snk_valid)[+]; snk_valid && data changed} |-> counts match
  t_rle_count: assert property (@(posedge clk_i) disable iff (reset_i || !src_ready_i)
    (snk_valid_i && s_gap_ready && (src_data_o != $past(src_data_o)))
    |-> (s_count_reg == s_count_src));

endmodule

bind rle_decode rle_decode_sva #(
  .g_WORD_WIDTH  (g_WORD_WIDTH),
  .g_COUNT_WIDTH (g_COUNT_WIDTH)
) rle_decode_sva_i (
  .clk_i       (clk_i),
  .reset_i     (reset_i),
  .snk_ready_o (snk_ready_o),
  .snk_valid_i (snk_valid_i),
  .snk_data_i  (snk_data_i),
  .src_ready_i (src_ready_i),
  .src_valid_o (src_valid_o),
  .src_data_o  (src_data_o)
);
