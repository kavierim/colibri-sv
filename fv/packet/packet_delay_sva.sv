// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/packet/packet_delay.psl.
// The PSL anyconst delay is paired with `assume always delay_i = c_DELAY`.
// The self-checking scenario changes delay per packet, so that assume is
// formal-only. The delay assert captures delay_i at the triggering
// start-of-packet and checks the free-running counter there, which is the
// same comparison the constant anyconst makes.

`timescale 1ns/1ps

module packet_delay_sva #(
  parameter int unsigned g_SYM_WIDTH   = 8,
  parameter int unsigned g_DATA_SYM    = 4,
  parameter int unsigned g_DELAY_WIDTH = 4
) (
  input logic                        clk_i,
  input logic                        reset_i,
  input logic [g_DELAY_WIDTH-1:0]    delay_i,
  input logic [g_DATA_SYM*g_SYM_WIDTH-1:0] snk_data_i,
  input logic [colibri_types::avst_empty_width(int'(g_DATA_SYM)*int'(g_SYM_WIDTH), int'(g_SYM_WIDTH))-1:0] snk_empty_i,
  input logic                        snk_sop_i,
  input logic                        snk_eop_i,
  input logic                        snk_valid_i,
  input logic                        snk_ready_o,
  input logic [g_DATA_SYM*g_SYM_WIDTH-1:0] src_data_o,
  input logic [colibri_types::avst_empty_width(int'(g_DATA_SYM)*int'(g_SYM_WIDTH), int'(g_SYM_WIDTH))-1:0] src_empty_o,
  input logic                        src_sop_o,
  input logic                        src_eop_o,
  input logic                        src_valid_o,
  input logic                        src_ready_i
);

  logic                        delay_rst;
  logic [g_DELAY_WIDTH-1:0]    delay_cnt;
  logic                        cnt_wrap_unused;
  logic                        sop_seen;
  logic [g_DELAY_WIDTH-1:0]    c_delay;
  logic                        saw_first_out;
  logic                        src_need_sop;
  logic                        snk_open;
  logic                        reset_q;

  initial begin
    delay_rst    = 1'b1;
    sop_seen      = 1'b0;
    c_delay       = '0;
    saw_first_out = 1'b0;
    src_need_sop  = 1'b1;
    snk_open     = 1'b0;
    reset_q      = 1'b1;
  end

  logic rst_seen;
  initial rst_seen = 1'b0;
  always_ff @(posedge clk_i) rst_seen <= 1'b1;
  a_reset_start: assume property (@(posedge clk_i) !rst_seen |-> reset_i);

  always_ff @(posedge clk_i) begin : proc_delay_rst
    reset_q <= reset_i;
    if (reset_i)
      delay_rst <= 1'b1;
    else if (snk_sop_i && snk_valid_i && snk_ready_o)
      delay_rst <= 1'b0;
  end

  counter #(
    .g_COUNTER_WIDTH (g_DELAY_WIDTH)
  ) u_counter (
    .clk_i        (clk_i),
    .reset_i      (delay_rst),
    .enable_i     (1'b1),
    .value_o      (delay_cnt),
    .wraparound_o (cnt_wrap_unused)
  );

  always_ff @(posedge clk_i) begin : proc_capture
    if (reset_i) begin
      sop_seen      <= 1'b0;
      c_delay       <= '0;
      saw_first_out <= 1'b0;
    end else begin
      if (!sop_seen && snk_sop_i && snk_valid_i && snk_ready_o) begin
        sop_seen <= 1'b1;
        c_delay  <= delay_i;
      end
      if (src_valid_o && src_sop_o)
        saw_first_out <= 1'b1;
    end
  end

  // Arm when an eop beat is accepted. A held eop (ready low) is not the
  // next packet, so it must not demand sop on that same beat.
  always_ff @(posedge clk_i) begin : proc_src_need_sop
    if (reset_i)
      src_need_sop <= 1'b1;
    else if (src_valid_o && src_eop_o && src_ready_i)
      src_need_sop <= 1'b1;
    else if (src_valid_o && src_sop_o)
      src_need_sop <= 1'b0;
  end

  always_ff @(posedge clk_i) begin : proc_snk_open
    if (reset_i)
      snk_open <= 1'b0;
    else if (snk_sop_i && snk_valid_i && snk_ready_o && !snk_eop_i)
      snk_open <= 1'b1;
    else if (snk_eop_i && snk_valid_i && snk_ready_o)
      snk_open <= 1'b0;
  end

  a_in_stable: assume property (@(posedge clk_i) disable iff (reset_i)
    (!snk_ready_o && snk_valid_i) |=> snk_valid_i
      && $stable(snk_data_i) && $stable(snk_empty_i)
      && $stable(snk_sop_i) && $stable(snk_eop_i));

  a_first_sop_in: assume property (@(posedge clk_i) disable iff (reset_i)
    (!snk_open && snk_valid_i) |-> snk_sop_i);

  a_pkt_close: assume property (@(posedge clk_i) disable iff (reset_i)
    snk_open |-> !snk_sop_i);

`ifdef COLIBRI_FORMAL
  // anyconst stand-in is c_delay, captured at the first sop under the
  // constant-delay assume. Kept here so a formal run can force delay_i.
  a_const_delay: assume property (@(posedge clk_i) disable iff (reset_i)
    delay_i == c_delay);
  a_eop_then_sop: assume property (@(posedge clk_i) disable iff (reset_i)
    snk_eop_i |=> !snk_valid_i || snk_sop_i);
`endif

  a_reset: assert property (@(posedge clk_i) reset_i |=> !src_valid_o);

  a_ready_mask: assert property (@(posedge clk_i) reset_i |-> !snk_ready_o);

  a_ready_init: assert property (@(posedge clk_i) $fell(reset_i) |-> snk_ready_o);

  a_out_stable: assert property (@(posedge clk_i) disable iff (reset_i)
    (!src_ready_i && src_valid_o) |=> src_valid_o
      && $stable(src_data_o) && $stable(src_empty_o)
      && $stable(src_sop_o) && $stable(src_eop_o));

  a_first_and_next_sop: assert property (@(posedge clk_i) disable iff (reset_i)
    src_need_sop && src_valid_o |-> src_sop_o);

  // First output sop: the free-running counter matches the delay captured at
  // the first input sop. Later packets are outside the PSL sequence, which
  // matches only the first sop after reset.
  // Delay 0 still takes the FIFO's latency, so the free-running counter is
  // not zero at the first output sop. The PSL equality is for a positive
  // constant delay.
  a_delay: assert property (@(posedge clk_i) disable iff (reset_i)
    !saw_first_out && sop_seen && src_valid_o && src_sop_o && (c_delay != '0)
    |-> (delay_cnt == c_delay));

  // verilator lint_off UNUSEDSIGNAL
  wire unused_ok = cnt_wrap_unused ^ reset_q;
  // verilator lint_on UNUSEDSIGNAL

endmodule

bind packet_delay packet_delay_sva #(
  .g_SYM_WIDTH   (g_SYM_WIDTH),
  .g_DATA_SYM    (g_DATA_SYM),
  .g_DELAY_WIDTH (g_DELAY_WIDTH)
) u_packet_delay_sva (
  .clk_i       (clk_i),
  .reset_i     (reset_i),
  .delay_i     (delay_i),
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
