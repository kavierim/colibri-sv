// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Packet-shape checks for be_remove_lead, translated from fv/misc/be_remove_lead.psl.

`timescale 1ns/1ps

module be_remove_lead_sva #(
  // PSL pins snk_data_i to 0 to simplify formal search. The VHDL scenario
  // drives a real payload, so that assume stays off unless a formal run
  // sets this parameter.
  parameter bit g_FORMAL_SIMPLIFY = 1'b0
) (
  input logic                       clk_i,
  input logic                       reset_i,
  input logic [2:0]                 shl_i,
  input logic                       snk_ready_o,
  input logic                       snk_valid_i,
  input logic                       snk_sop_i,
  input logic                       snk_eop_i,
  input logic [1:0]                 snk_empty_i,
  input logic [31:0]                snk_data_i,
  input logic                       src_ready_i,
  input logic                       src_valid_o,
  input logic                       src_sop_o,
  input logic                       src_eop_o,
  input logic [1:0]                 src_empty_o
);

  localparam int c_WORD_BYTES = 4;
  localparam int c_DATA_BYTES = 4;

  typedef enum logic [1:0] {
    PKT_IDLE   = 2'd0,
    PKT_SINGLE = 2'd1,
    PKT_MULTI  = 2'd2
  } pkt_t;

  pkt_t s_snk_pkt;
  pkt_t s_src_pkt;

  initial begin
    s_snk_pkt = PKT_IDLE;
    s_src_pkt = PKT_IDLE;
    assume (reset_i == 1'b1);
  end

  always_ff @(posedge clk_i) begin : proc_snk_pkt
    if (reset_i)
      s_snk_pkt <= PKT_IDLE;
    else if (snk_valid_i && snk_ready_o) begin
      if (snk_sop_i && !snk_eop_i)
        s_snk_pkt <= PKT_MULTI;
      else if (!snk_sop_i && snk_eop_i)
        s_snk_pkt <= PKT_IDLE;
      else if (snk_sop_i && snk_eop_i)
        s_snk_pkt <= PKT_SINGLE;
    end
  end

  always_ff @(posedge clk_i) begin : proc_src_pkt
    if (reset_i)
      s_src_pkt <= PKT_IDLE;
    else if (src_valid_o && src_ready_i) begin
      if (src_sop_o && !src_eop_o)
        s_src_pkt <= PKT_MULTI;
      else if (!src_sop_o && src_eop_o)
        s_src_pkt <= PKT_IDLE;
      else if (src_sop_o && src_eop_o)
        s_src_pkt <= PKT_SINGLE;
    end
  end

  assume property (@(posedge clk_i) (s_snk_pkt == PKT_MULTI) |-> !snk_sop_i);
  assume property (@(posedge clk_i)
    (!snk_sop_i && (s_snk_pkt != PKT_MULTI)) |-> (!snk_valid_i && !snk_ready_o));

  assert property (@(posedge clk_i)
    (!reset_i && (s_src_pkt == PKT_IDLE) && src_ready_i && src_valid_o) |-> src_sop_o);
  assert property (@(posedge clk_i)
    (!reset_i && (s_src_pkt == PKT_MULTI) && src_ready_i && src_valid_o) |-> !src_sop_o);
  cover property (@(posedge clk_i)
    !reset_i && src_ready_i && src_valid_o && src_sop_o && src_eop_o);
  assert property (@(posedge clk_i)
    (!reset_i && src_eop_o && src_ready_i && src_valid_o) |-> (int'(src_empty_o) < c_WORD_BYTES));

  assume property (@(posedge clk_i) g_FORMAL_SIMPLIFY |-> (snk_data_i == '0));
  assume property (@(posedge clk_i) int'(shl_i) <= c_WORD_BYTES);
  assume property (@(posedge clk_i) !snk_eop_i |-> (snk_empty_i == '0));
  assume property (@(posedge clk_i)
    (snk_eop_i && snk_sop_i) |-> ((c_DATA_BYTES - int'(snk_empty_i)) > int'(shl_i)));
  assume property (@(posedge clk_i)
    (snk_eop_i && snk_sop_i) |-> (int'(shl_i) < c_WORD_BYTES));
  assume property (@(posedge clk_i)
    (s_snk_pkt == PKT_MULTI) |-> (shl_i == $past(shl_i)));

endmodule

bind be_remove_lead be_remove_lead_sva be_remove_lead_sva_i (.*);
