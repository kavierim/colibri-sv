// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/packet/header_add.psl.
// Tool 5.020 checks assume as assert. The PSL assume that forces ready
// low outside a packet does not hold on this pipeline (ready stays high while
// idle). That constraint is kept under COLIBRI_FORMAL.

`timescale 1ns/1ps

module header_add_sva #(
  parameter int unsigned g_DATA_WIDTH = 32
) (
  input logic clk_i,
  input logic reset_i,
  input logic snk_sop_i,
  input logic snk_eop_i,
  input logic snk_valid_i,
  input logic snk_ready_o,
  input logic src_sop_o,
  input logic src_eop_o,
  input logic src_valid_o,
  input logic src_ready_i,
  input logic [colibri_types::avst_empty_width(int'(g_DATA_WIDTH), 8)-1:0] src_empty_o
);

  localparam int c_WORD_BYTES = int'(g_DATA_WIDTH) / 8;

  typedef enum logic [1:0] {
    PKT_IDLE   = 2'd0,
    PKT_SINGLE = 2'd1,
    PKT_MULTI  = 2'd2
  } pkt_t;

  pkt_t s_snk_pkt = PKT_IDLE;
  pkt_t s_src_pkt = PKT_IDLE;

  // PSL: assume {reset_i}; evaluated on the first clock only.
  logic rst_seen;
  initial rst_seen = 1'b0;
  always_ff @(posedge clk_i) rst_seen <= 1'b1;
  a_reset_start: assume property (@(posedge clk_i) !rst_seen |-> reset_i);

  always_ff @(posedge clk_i) begin : proc_snk_pkt
    if (reset_i) begin
      s_snk_pkt <= PKT_IDLE;
    end else if (snk_valid_i && snk_ready_o) begin
      if (snk_sop_i && !snk_eop_i)
        s_snk_pkt <= PKT_MULTI;
      else if (!snk_sop_i && snk_eop_i)
        s_snk_pkt <= PKT_IDLE;
      else if (snk_sop_i && snk_eop_i)
        s_snk_pkt <= PKT_SINGLE;
    end
  end

  always_ff @(posedge clk_i) begin : proc_src_pkt
    if (reset_i) begin
      s_src_pkt <= PKT_IDLE;
    end else if (src_valid_o && src_ready_i) begin
      if (src_sop_o && !src_eop_o)
        s_src_pkt <= PKT_MULTI;
      else if (!src_sop_o && src_eop_o)
        s_src_pkt <= PKT_IDLE;
      else if (src_sop_o && src_eop_o)
        s_src_pkt <= PKT_SINGLE;
    end
  end

  a_snk_no_sop_in_multi: assume property (@(posedge clk_i)
    s_snk_pkt == PKT_MULTI |-> !snk_sop_i);

  a_snk_no_valid_outside: assume property (@(posedge clk_i)
    (!snk_sop_i && s_snk_pkt != PKT_MULTI) |-> !snk_valid_i);

`ifdef COLIBRI_FORMAL
  // PSL also required !snk_ready_o. Ready is a DUT output and stays 1 while idle.
  a_snk_no_ready_outside: assume property (@(posedge clk_i)
    (!snk_sop_i && s_snk_pkt != PKT_MULTI) |-> !snk_ready_o);
`endif

  a_valid_out_sop: assert property (@(posedge clk_i)
    (!reset_i && s_src_pkt == PKT_IDLE && src_ready_i && src_valid_o) |-> src_sop_o);

  a_valid_out_multi: assert property (@(posedge clk_i)
    (!reset_i && s_src_pkt == PKT_MULTI && src_ready_i && src_valid_o) |-> !src_sop_o);

  c_valid_out_single: cover property (@(posedge clk_i)
    !reset_i && src_ready_i && src_valid_o && src_sop_o && src_eop_o);

  a_empty_out: assert property (@(posedge clk_i)
    (!reset_i && src_eop_o && src_ready_i && src_valid_o) |-> (int'(src_empty_o) < c_WORD_BYTES));

endmodule

bind header_add header_add_sva #(
  .g_DATA_WIDTH (g_DATA_WIDTH)
) u_header_add_sva (
  .clk_i       (clk_i),
  .reset_i     (reset_i),
  .snk_sop_i   (snk_sop_i),
  .snk_eop_i   (snk_eop_i),
  .snk_valid_i (snk_valid_i),
  .snk_ready_o (snk_ready_o),
  .src_sop_o   (src_sop_o),
  .src_eop_o   (src_eop_o),
  .src_valid_o (src_valid_o),
  .src_ready_i (src_ready_i),
  .src_empty_o (src_empty_o)
);
