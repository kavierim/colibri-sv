// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/pipes/arbiter.psl.
// The VHDL field `priority` is `priority_q` in the SystemVerilog RTL.

`timescale 1ns/1ps

module arbiter_sva #(
  parameter int g_NUM_INPUTS = 4
) (
  input logic                         clk_i,
  input logic                         reset_i,
  input logic [g_NUM_INPUTS-1:0]      requests_i,
  input logic [g_NUM_INPUTS-1:0]      grants_o,
  input logic [g_NUM_INPUTS-1:0]      priority_q
);

  // PSL: assume {reset_i; not reset_i}. Verilator 5.020 has no ## delay.
  logic [1:0] rst_phase;
  initial rst_phase = 2'd0;
  always_ff @(posedge clk_i) begin
    if (rst_phase < 2'd2)
      rst_phase <= rst_phase + 2'd1;
  end

  a_reset_c0: assume property (@(posedge clk_i) rst_phase == 2'd0 |-> reset_i);
  a_reset_c1: assume property (@(posedge clk_i) rst_phase == 2'd1 |-> !reset_i);
  a_reset_hold: assume property (@(posedge clk_i) !reset_i |=> !reset_i);

  // Previous-cycle copies stand in for PSL prev() and the {idle; ...} prefix.
  logic                    prev_idle;
  logic [g_NUM_INPUTS-1:0] prev_rg;
  logic [g_NUM_INPUTS-1:0] prev_grant;
  logic [g_NUM_INPUTS-1:0] prev_pri;
  logic                    rr_pend;

  initial begin
    prev_idle  = 1'b0;
    prev_rg    = '0;
    prev_grant = '0;
    prev_pri   = '0;
    rr_pend    = 1'b0;
  end

  always_ff @(posedge clk_i) begin
    prev_idle  <= !reset_i;
    prev_rg    <= requests_i & grants_o;
    prev_grant <= grants_o;
    prev_pri   <= priority_q;
    // Armed when the prior cycle was out of reset and the granted-request mask changed.
    rr_pend    <= prev_idle && ((requests_i & grants_o) != prev_rg);
  end

  a_single_grant: assert property (@(posedge clk_i)
    !reset_i |-> $onehot0(grants_o));

  a_req_grant: assert property (@(posedge clk_i)
    ($onehot(requests_i) && !reset_i) |-> $onehot(requests_i & grants_o));

  a_no_grant_if_no_req: assert property (@(posedge clk_i)
    (!(|requests_i) && !reset_i) |-> !(|grants_o));

  // {idle; previously granted request still present} |-> grant unchanged.
  a_stable_grant: assert property (@(posedge clk_i)
    prev_idle && (|(prev_rg & requests_i)) |-> (grants_o == prev_grant));

  // {idle; granted request dropped, some request remains} |-> grant changes.
  a_change_grant: assert property (@(posedge clk_i)
    prev_idle && !(|(prev_rg & requests_i)) && (|requests_i) |-> (grants_o != prev_grant));

  // Round-robin: a change in the granted-request set rotates priority next cycle.
  a_round_robin: assert property (@(posedge clk_i)
    rr_pend |-> (priority_q != prev_pri));

endmodule

bind arbiter arbiter_sva #(
  .g_NUM_INPUTS (g_NUM_INPUTS)
) u_arbiter_sva (
  .clk_i      (clk_i),
  .reset_i    (reset_i),
  .requests_i (requests_i),
  .grants_o   (grants_o),
  .priority_q (priority_q)
);
