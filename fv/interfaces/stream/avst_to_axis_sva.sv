// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit avst_to_axis_vu, bound into avst_to_axis.
module avst_to_axis_sva #(
  parameter int unsigned g_DATA_WIDTH = 32,
  localparam int c_KEEP_W  = colibri_utils::downto_width(int'(g_DATA_WIDTH) / 8),
  localparam int c_EMPTY_W = colibri_utils::downto_width(
    colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))
) (
  input logic                     clk_i,
  input logic                     reset_i,
  input logic                     snk_ready_o,
  input logic                     snk_valid_i,
  input logic                     snk_sop_i,
  input logic                     snk_eop_i,
  input logic [c_EMPTY_W-1:0]     snk_empty_i,
  input logic [g_DATA_WIDTH-1:0]  snk_data_i,
  input logic                     src_tready_i,
  input logic                     src_tvalid_o,
  input logic                     src_tlast_o,
  input logic [c_KEEP_W-1:0]      src_tkeep_o,
  input logic [g_DATA_WIDTH-1:0]  src_tdata_o
);

  typedef enum logic [1:0] {
    PKT_IDLE   = 2'd0,
    PKT_SINGLE = 2'd1,
    PKT_MULTI  = 2'd2
  } pkt_t;

  pkt_t s_snk_pkt = PKT_IDLE;
  pkt_t s_src_pkt = PKT_IDLE;
  logic first_cycle = 1'b1;

  logic [c_KEEP_W-1:0] keep_shift;
  logic [c_KEEP_W-1:0] keep_oh;

  if (c_KEEP_W <= 1) begin : gen_keep_shift_narrow
    assign keep_shift = '0;
  end else begin : gen_keep_shift
    assign keep_shift = {1'b0, src_tkeep_o[c_KEEP_W-1:1]};
  end
  assign keep_oh = src_tkeep_o ^ keep_shift;

  // verilator lint_off UNUSEDSIGNAL
  wire unused_data = ^{snk_empty_i, snk_data_i, src_tdata_o, s_src_pkt};
  // verilator lint_on UNUSEDSIGNAL

  always_ff @(posedge clk_i) begin : proc_first
    first_cycle <= 1'b0;
  end

  always_ff @(posedge clk_i) begin : proc_snk_pkt
    pkt_t v;
    v = s_snk_pkt;
    if (reset_i)
      v = PKT_IDLE;
    else if (snk_valid_i && snk_ready_o) begin
      if (snk_sop_i && !snk_eop_i)
        v = PKT_MULTI;
      else if (!snk_sop_i && snk_eop_i)
        v = PKT_IDLE;
      else if (snk_sop_i && snk_eop_i)
        v = PKT_SINGLE;
    end
    s_snk_pkt <= v;
  end

  always_ff @(posedge clk_i) begin : proc_src_pkt
    pkt_t v;
    v = s_src_pkt;
    if (reset_i)
      v = PKT_IDLE;
    else begin
      if (s_src_pkt == PKT_SINGLE)
        v = PKT_IDLE;
      if (src_tvalid_o && src_tready_i) begin
        if (!src_tlast_o)
          v = PKT_MULTI;
        else if ((s_src_pkt == PKT_MULTI) && src_tlast_o)
          v = PKT_IDLE;
        else if (src_tlast_o)
          v = PKT_SINGLE;
      end
    end
    s_src_pkt <= v;
  end

  assume property (@(posedge clk_i) first_cycle |-> reset_i);
  assume property (@(posedge clk_i) first_cycle |=> !reset_i);
  assume property (@(posedge clk_i) !reset_i |=> !reset_i);

  // Packet shape the driver is allowed to present.
  assume property (@(posedge clk_i) (s_snk_pkt == PKT_MULTI) |-> !snk_sop_i);
  assume property (@(posedge clk_i)
    !snk_sop_i && (s_snk_pkt != PKT_MULTI) |-> !snk_valid_i && !snk_ready_o);

  // Keep is full except on the last beat.
  assume property (@(posedge clk_i) !src_tlast_o |-> (src_tkeep_o == {c_KEEP_W{1'b1}}));

  assert property (@(posedge clk_i)
    !reset_i && src_tready_i && src_tvalid_o |-> $onehot(keep_oh));
  assert property (@(posedge clk_i)
    !reset_i && src_tready_i && src_tvalid_o |-> (src_tkeep_o != '0));

endmodule

bind avst_to_axis avst_to_axis_sva #(
  .g_DATA_WIDTH (g_DATA_WIDTH)
) avst_to_axis_sva_i (
  .clk_i        (clk_i),
  .reset_i      (reset_i),
  .snk_ready_o  (snk_ready_o),
  .snk_valid_i  (snk_valid_i),
  .snk_sop_i    (snk_sop_i),
  .snk_eop_i    (snk_eop_i),
  .snk_empty_i  (snk_empty_i),
  .snk_data_i   (snk_data_i),
  .src_tready_i (src_tready_i),
  .src_tvalid_o (src_tvalid_o),
  .src_tlast_o  (src_tlast_o),
  .src_tkeep_o  (src_tkeep_o),
  .src_tdata_o  (src_tdata_o)
);
