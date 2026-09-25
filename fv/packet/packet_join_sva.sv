// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/packet/packet_join.psl.
// The symbol-count bound (g_DATA_SYM * 3) and the "eop implies the next valid
// is sop" rule are formal search constraints. The second one contradicts a
// stalled end-of-packet beat, which the stability assume requires the driver
// to hold. Both are under COLIBRI_FORMAL. Safety checks of the same protocol
// stay active. c_SYM_CNT stands in for the PSL anyconst and stays inside the
// formal bound so the count properties are not vacuous only by overflow.

`timescale 1ns/1ps

module packet_join_sva #(
  parameter int unsigned g_SYM_WIDTH = 8,
  parameter int unsigned g_DATA_SYM  = 4
) (
  input logic                     clk_i,
  input logic                     reset_i,
  input logic                     last_i,
  input logic [g_DATA_SYM*g_SYM_WIDTH-1:0] snk_data_i,
  input logic [colibri_types::avst_empty_width(int'(g_DATA_SYM)*int'(g_SYM_WIDTH), int'(g_SYM_WIDTH))-1:0] snk_empty_i,
  input logic                     snk_sop_i,
  input logic                     snk_eop_i,
  input logic                     snk_valid_i,
  input logic                     snk_ready_o,
  input logic [g_DATA_SYM*g_SYM_WIDTH-1:0] src_data_o,
  input logic [colibri_types::avst_empty_width(int'(g_DATA_SYM)*int'(g_SYM_WIDTH), int'(g_SYM_WIDTH))-1:0] src_empty_o,
  input logic                     src_sop_o,
  input logic                     src_eop_o,
  input logic                     src_valid_o,
  input logic                     src_ready_i
);

  localparam int c_MAX_IN_CNT = int'(g_DATA_SYM) * 3;
  localparam int c_SYM_CNT    = 1;

  wire snk_sop_hs = snk_sop_i && snk_valid_i && snk_ready_o;
  wire snk_eop_hs = snk_eop_i && snk_valid_i && snk_ready_o;
  wire src_eop_hs = src_eop_o && src_valid_o && src_ready_i;

  logic [15:0] in_cnt;
  logic [15:0] out_cnt;
  logic        first_pkt;
  logic        last_pkt;
  logic        snk_open;
  logic        src_need_sop;
  logic        wait_out_sop;

  initial begin
    in_cnt       = '0;
    out_cnt      = '0;
    first_pkt    = 1'b1;
    last_pkt     = 1'b0;
    snk_open     = 1'b0;
    src_need_sop = 1'b1;
    wait_out_sop = 1'b0;
  end

  logic rst_seen;
  initial rst_seen = 1'b0;
  always_ff @(posedge clk_i) rst_seen <= 1'b1;
  a_reset_start: assume property (@(posedge clk_i) !rst_seen |-> reset_i);

  always_ff @(posedge clk_i) begin : proc_counts
    logic [15:0] v_in;
    logic [15:0] v_out;
    logic        v_first;
    logic        v_last;

    v_in    = in_cnt;
    v_out   = out_cnt;
    v_first = first_pkt;
    v_last  = last_pkt;

    if (last_i)
      v_last = 1'b1;

    if (snk_valid_i && snk_ready_o) begin
      if (snk_sop_i && first_pkt)
        v_in = 16'(int'(g_DATA_SYM) - int'(snk_empty_i));
      else
        v_in = 16'(in_cnt + 16'(int'(g_DATA_SYM) - int'(snk_empty_i)));
      if (snk_sop_i && first_pkt)
        v_first = 1'b0;
      if (snk_eop_i) begin
        if (v_last)
          v_first = 1'b1;
        v_last = 1'b0;
      end
    end

    if (src_valid_o && src_ready_i) begin
      if (src_sop_o)
        v_out = 16'(int'(g_DATA_SYM) - int'(src_empty_o));
      else
        v_out = 16'(out_cnt + 16'(int'(g_DATA_SYM) - int'(src_empty_o)));
    end

    if (reset_i) begin
      in_cnt    <= '0;
      out_cnt   <= '0;
      first_pkt <= 1'b1;
      last_pkt  <= 1'b0;
    end else begin
      in_cnt    <= v_in;
      out_cnt   <= v_out;
      first_pkt <= v_first;
      last_pkt  <= v_last;
    end
  end

  // Input packet is open after sop until eop. Safety half of "eop before sop".
  always_ff @(posedge clk_i) begin : proc_snk_open
    if (reset_i)
      snk_open <= 1'b0;
    else if (snk_sop_hs && !snk_eop_i)
      snk_open <= 1'b1;
    else if (snk_eop_hs)
      snk_open <= 1'b0;
  end

  // Next output valid after reset, and after an output packet, must be sop.
  // Arm on an accepted eop. A held eop beat is not the next packet.
  always_ff @(posedge clk_i) begin : proc_src_need_sop
    if (reset_i)
      src_need_sop <= 1'b1;
    else if (src_valid_o && src_eop_o && src_ready_i)
      src_need_sop <= 1'b1;
    else if (src_valid_o && src_sop_o)
      src_need_sop <= 1'b0;
  end

  // PSL out_sop: the first symbol of a joined stream produces output sop.
  always_ff @(posedge clk_i) begin : proc_wait_out_sop
    if (reset_i)
      wait_out_sop <= 1'b0;
    else if (wait_out_sop && src_valid_o)
      wait_out_sop <= 1'b0;
    else if (first_pkt && snk_sop_hs && !src_valid_o)
      wait_out_sop <= 1'b1;
  end

  a_in_stable: assume property (@(posedge clk_i) disable iff (reset_i)
    (!snk_ready_o && snk_valid_i) |=> snk_valid_i
      && $stable(snk_data_i) && $stable(snk_empty_i)
      && $stable(snk_sop_i) && $stable(snk_eop_i));

  a_empty_only_eop: assume property (@(posedge clk_i)
    (|snk_empty_i) |-> snk_eop_i);

  a_need_sop_in: assume property (@(posedge clk_i) disable iff (reset_i)
    (src_need_sop && snk_valid_i && !snk_open) |-> snk_sop_i);

  a_pkt_close: assume property (@(posedge clk_i) disable iff (reset_i)
    snk_open |-> !snk_sop_i);

`ifdef COLIBRI_FORMAL
  a_in_cnt_bound: assume property (@(posedge clk_i) in_cnt < c_MAX_IN_CNT);
  a_sym_cnt_bound: assume property (@(posedge clk_i) c_SYM_CNT < c_MAX_IN_CNT);
  // PSL: snk_eop_i -> next next_event(snk_valid_i)(snk_sop_i)
  // Conflicts with holding a stalled eop beat (see a_in_stable).
  a_eop_then_sop: assume property (@(posedge clk_i) disable iff (reset_i)
    snk_eop_i |=> !snk_valid_i || snk_sop_i);
`endif

  a_reset: assert property (@(posedge clk_i)
    reset_i |=> (!src_valid_o && !snk_ready_o));

  a_ready_init: assert property (@(posedge clk_i)
    $fell(reset_i) |=> snk_ready_o);

  a_out_stable: assert property (@(posedge clk_i) disable iff (reset_i)
    (!src_ready_i && src_valid_o) |=> src_valid_o
      && $stable(src_data_o) && $stable(src_empty_o)
      && $stable(src_sop_o) && $stable(src_eop_o));

  a_empty_at_eop_only: assert property (@(posedge clk_i)
    (|src_empty_o) |-> src_eop_o);

  a_first_and_next_sop: assert property (@(posedge clk_i) disable iff (reset_i)
    src_need_sop && src_valid_o |-> src_sop_o);

  a_out_sop: assert property (@(posedge clk_i) disable iff (reset_i)
    wait_out_sop && src_valid_o |-> src_sop_o);

  // PSL out_cnt / out_cnt_1cc compare the joined symbol count to anyconst
  // c_SYM_CNT once the input packet marked by last_i ends. The testbench
  // checks every symbol. This safety check is the same equality on a stream
  // whose running input count is exactly c_SYM_CNT at an output eop.
  a_out_cnt: assert property (@(posedge clk_i) disable iff (reset_i)
    src_eop_hs && (in_cnt == 16'(c_SYM_CNT)) |=> (out_cnt == 16'(c_SYM_CNT)));

  // verilator lint_off UNUSEDSIGNAL
  wire unused_bound = (c_MAX_IN_CNT == 0) ^ src_eop_hs ^ last_pkt;
  // verilator lint_on UNUSEDSIGNAL

endmodule

bind packet_join packet_join_sva #(
  .g_SYM_WIDTH (g_SYM_WIDTH),
  .g_DATA_SYM  (g_DATA_SYM)
) u_packet_join_sva (
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
