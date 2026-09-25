// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit avst_ram_read_vu, bound into avst_ram_read.
// anyconst equalities are written as direct comparisons so every value is checked.
// Sequence bounds are finite so a simulation attempt can finish.
module avst_ram_read_sva #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 16,
  localparam int c_ADDR_RAW   = colibri_utils::log2ceil(int'(g_RAM_DEPTH)),
  localparam int c_ADDR_W     = colibri_utils::downto_width(c_ADDR_RAW),
  localparam int c_WORD_CNT_W = c_ADDR_RAW + 1,
  localparam int c_LEN_W      = colibri_utils::log2ceil(
    int'(g_RAM_DEPTH) * int'(g_WORD_BYTES) + 1),
  localparam int c_DATA_W     = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W    = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH))
) (
  input logic                    clk_i,
  input logic                    reset_i,
  input logic [c_DATA_W-1:0]     src_data_o,
  input logic [c_EMPTY_W-1:0]    src_empty_o,
  input logic                    src_sop_o,
  input logic                    src_eop_o,
  input logic                    src_valid_o,
  input logic                    src_ready_i,
  input logic [c_ADDR_W-1:0]     start_addr_i,
  input logic [c_LEN_W-1:0]      length_i,
  input logic                    start_i,
  input logic                    stop_i,
  input logic                    busy_o,
  input logic                    rd_en_o,
  input logic [c_ADDR_W-1:0]     rd_addr_o,
  input logic [c_DATA_W-1:0]     rd_data_i,
  input logic [c_WORD_CNT_W-1:0] word_cnt
);

  localparam int c_SEQ = 512;

  logic                    rd_valid = 1'b0;
  logic                    back_pressure;
  logic                    handshake;
  logic                    sop_hs;
  logic                    eop_hs;
  logic                    in_flight_valid;
  logic                    rd_start;
  logic [c_LEN_W-1:0]      rd_cnt = '0;
  logic [c_LEN_W-1:0]      out_cnt = '0;
  int                      pkt_cnt = 0;
  logic                    first_cycle = 1'b1;

  assign back_pressure  = src_valid_o && !src_ready_i;
  assign handshake      = src_valid_o && src_ready_i;
  assign sop_hs         = src_sop_o && handshake;
  assign eop_hs         = src_eop_o && handshake;
  assign in_flight_valid = src_valid_o && (!src_sop_o || src_ready_i);
  assign rd_start       = start_i && !busy_o && !stop_i && !reset_i;

  // verilator lint_off UNUSEDSIGNAL
  wire unused_ports = ^{start_addr_i, rd_valid};
  // verilator lint_on UNUSEDSIGNAL

  always_ff @(posedge clk_i) begin : proc_first
    first_cycle <= 1'b0;
    rd_valid    <= rd_en_o && !reset_i;
  end

  always_ff @(posedge clk_i) begin : proc_counts
    int v_pkt;
    if (reset_i || rd_start)
      rd_cnt <= '0;
    else if (rd_en_o)
      rd_cnt <= rd_cnt + c_LEN_W'(g_WORD_BYTES);

    if (reset_i || eop_hs)
      out_cnt <= '0;
    else if (handshake)
      out_cnt <= out_cnt + c_LEN_W'(g_WORD_BYTES) - c_LEN_W'(src_empty_o);

    v_pkt = pkt_cnt;
    if (rd_start)
      v_pkt = v_pkt + 1;
    if (eop_hs) begin
      if (stop_i)
        v_pkt = 0;
      else
        v_pkt = v_pkt - 1;
    end
    if (stop_i && !in_flight_valid)
      v_pkt = 0;
    else if (stop_i && (v_pkt > 1))
      v_pkt = 1;
    if (reset_i)
      v_pkt = 0;
    pkt_cnt <= v_pkt;
  end

  function automatic logic [c_EMPTY_W-1:0] empty_of(input logic [c_LEN_W-1:0] len);
    int modv;
    modv = int'(len) % int'(g_WORD_BYTES);
    // A full last word has empty 0. Subtracting the modulus from the word
    // size overflows a 1-byte word; that case is empty 0 as well.
    if (modv == 0)
      return '0;
    return c_EMPTY_W'(int'(g_WORD_BYTES) - modv);
  endfunction

  assume property (@(posedge clk_i) first_cycle |-> reset_i);

  assert property (@(posedge clk_i)
    reset_i |=> !busy_o && !src_valid_o && !rd_en_o);

  assert property (@(posedge clk_i) disable iff (reset_i)
    rd_start && !back_pressure |=>
      rd_en_o && (busy_o || $past(stop_i) || ($past(length_i) <= c_LEN_W'(g_WORD_BYTES))));

  // This simulator rejects local variables, cycle delays, and goto repetition.
  // The same intent is checked with sampled addresses and chained implications.
  logic                    addr_seen = 1'b0;
  logic [c_ADDR_W-1:0]     addr_cap = '0;
  logic                    wait_sop = 1'b0;
  logic                    cap_on = 1'b0;
  logic [c_LEN_W-1:0]      cap_len = '0;

  always_ff @(posedge clk_i) begin : proc_addr_incr
    if (reset_i || !busy_o) begin
      addr_seen <= 1'b0;
    end else if (rd_en_o) begin
      if (addr_seen)
        assert (rd_addr_o == (addr_cap + c_ADDR_W'(1)));
      addr_cap  <= rd_addr_o;
      addr_seen <= 1'b1;
    end
  end

  always_ff @(posedge clk_i) begin : proc_sop_eop
    if (reset_i) begin
      wait_sop <= 1'b0;
      cap_on   <= 1'b0;
    end else begin
      if (rd_start && !src_valid_o)
        wait_sop <= 1'b1;
      if (wait_sop && src_valid_o) begin
        assert (src_sop_o);
        wait_sop <= 1'b0;
      end
      if (stop_i) begin
        cap_on <= 1'b0;
      end else if (rd_start && (length_i != '0) &&
                   (((pkt_cnt == 0) && !eop_hs) || ((pkt_cnt == 1) && eop_hs))) begin
        cap_len <= length_i;
        cap_on  <= 1'b1;
      end
      if (cap_on && src_valid_o &&
          ((cap_len - out_cnt) <= c_LEN_W'(g_WORD_BYTES)))
        assert (src_eop_o);
      if (cap_on && src_eop_o) begin
        assert (src_empty_o == empty_of(cap_len));
        cap_on <= 1'b0;
      end
    end
  end

  assert property (@(posedge clk_i) disable iff (reset_i || stop_i)
    $past(rd_en_o && !back_pressure) && !back_pressure |=>
      src_valid_o && (src_data_o == $past(rd_data_i)));

  assert property (@(posedge clk_i) pkt_cnt == 4 |-> src_eop_o && src_valid_o && busy_o);
  assert property (@(posedge clk_i) pkt_cnt < 5);

  assert property (@(posedge clk_i) src_eop_o || src_sop_o |-> src_valid_o);

  logic wait_stop_eop = 1'b0;
  int   sop_gap = 0;

  always_ff @(posedge clk_i) begin : proc_stop_eop
    if (reset_i) begin
      wait_stop_eop <= 1'b0;
      sop_gap       <= 0;
    end else begin
      if (stop_i && in_flight_valid && !eop_hs)
        wait_stop_eop <= 1'b1;
      if (wait_stop_eop && handshake) begin
        assert (src_eop_o);
        wait_stop_eop <= 1'b0;
      end
      if (eop_hs)
        sop_gap <= 0;
      else if (sop_hs && !src_eop_o)
        sop_gap <= 1;
      else if (sop_gap != 0) begin
        sop_gap <= sop_gap + 1;
        assert (sop_gap < c_SEQ);
      end
    end
  end

  assert property (@(posedge clk_i) (|src_empty_o) |-> src_eop_o);

  assert property (@(posedge clk_i) disable iff (reset_i)
    back_pressure && !src_sop_o |=>
      $stable(src_data_o) && $stable(src_valid_o) && $stable(src_sop_o) &&
      ($stable(src_eop_o) || $past(stop_i)) && $stable(src_empty_o));

  // A started read reaches a last word, and busy is low on that word.
  assert property (@(posedge clk_i) disable iff (reset_i || stop_i)
    rd_en_o && cap_on && ((cap_len - rd_cnt) <= c_LEN_W'(g_WORD_BYTES)) |-> !busy_o);

  // Weak until: busy holds on the cycle after a zero-length start.
  // The testbenches do not start a zero-length read.
  assert property (@(posedge clk_i) disable iff (reset_i)
    rd_start && (length_i == '0) |=> busy_o);

  assert property (@(posedge clk_i) stop_i |=> !busy_o);

  // Formal cover of the word counter passing 0 then 3 while busy.
  cover property (@(posedge clk_i) busy_o && (word_cnt == c_WORD_CNT_W'(3)));

endmodule

bind avst_ram_read avst_ram_read_sva #(
  .g_BYTE_WIDTH (g_BYTE_WIDTH),
  .g_WORD_BYTES (g_WORD_BYTES),
  .g_RAM_DEPTH  (g_RAM_DEPTH)
) avst_ram_read_sva_i (
  .clk_i        (clk_i),
  .reset_i      (reset_i),
  .src_data_o   (src_data_o),
  .src_empty_o  (src_empty_o),
  .src_sop_o    (src_sop_o),
  .src_eop_o    (src_eop_o),
  .src_valid_o  (src_valid_o),
  .src_ready_i  (src_ready_i),
  .start_addr_i (start_addr_i),
  .length_i     (length_i),
  .start_i      (start_i),
  .stop_i       (stop_i),
  .busy_o       (busy_o),
  .rd_en_o      (rd_en_o),
  .rd_addr_o    (rd_addr_o),
  .rd_data_i    (rd_data_i),
  .word_cnt     (r.word_cnt)
);
