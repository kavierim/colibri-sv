// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit axis_to_avst_vu, bound into axis_to_avst.
module axis_to_avst_sva #(
  parameter int unsigned g_DATA_WIDTH = 32,
  localparam int c_KEEP_W     = colibri_utils::downto_width(int'(g_DATA_WIDTH) / 8),
  localparam int c_EMPTY_W    = colibri_utils::downto_width(
    colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8)),
  localparam int c_WORD_BYTES = int'(g_DATA_WIDTH) / 8
) (
  input logic                     clk_i,
  input logic                     reset_i,
  input logic                     snk_tready_o,
  input logic                     snk_tvalid_i,
  input logic                     snk_tlast_i,
  input logic [c_KEEP_W-1:0]      snk_tkeep_i,
  input logic [g_DATA_WIDTH-1:0]  snk_tdata_i,
  input logic                     src_ready_i,
  input logic                     src_valid_o,
  input logic                     src_sop_o,
  input logic                     src_eop_o,
  input logic [c_EMPTY_W-1:0]     src_empty_o,
  input logic [g_DATA_WIDTH-1:0]  src_data_o
);

  typedef enum logic [1:0] {
    PKT_IDLE   = 2'd0,
    PKT_SINGLE = 2'd1,
    PKT_MULTI  = 2'd2
  } pkt_t;

  pkt_t s_snk_pkt = PKT_IDLE;
  pkt_t s_src_pkt = PKT_IDLE;
  int   s_src_word_cnt = 0;
  logic first_cycle = 1'b1;

  logic [c_KEEP_W-1:0] keep_shift;
  logic [c_KEEP_W-1:0] keep_oh;

  if (c_KEEP_W <= 1) begin : gen_keep_shift_narrow
    assign keep_shift = '0;
  end else begin : gen_keep_shift
    assign keep_shift = {1'b0, snk_tkeep_i[c_KEEP_W-1:1]};
  end
  assign keep_oh = snk_tkeep_i ^ keep_shift;

  // snk_tdata_i / src_data_o are observed by the surrounding testbench.
  // verilator lint_off UNUSEDSIGNAL
  wire unused_data = ^{snk_tdata_i, src_data_o, s_src_word_cnt};
  // verilator lint_on UNUSEDSIGNAL

  always_ff @(posedge clk_i) begin : proc_first
    first_cycle <= 1'b0;
  end

  // Incoming packet class. A single-beat packet returns to idle on the next cycle.
  always_ff @(posedge clk_i) begin : proc_snk_pkt
    pkt_t v;
    v = s_snk_pkt;
    if (reset_i)
      v = PKT_IDLE;
    else begin
      if (s_snk_pkt == PKT_SINGLE)
        v = PKT_IDLE;
      if (snk_tvalid_i && snk_tready_o) begin
        if (!snk_tlast_i)
          v = PKT_MULTI;
        else if ((s_snk_pkt == PKT_MULTI) && snk_tlast_i)
          v = PKT_IDLE;
        else if (snk_tlast_i)
          v = PKT_SINGLE;
      end
    end
    s_snk_pkt <= v;
  end

  always_ff @(posedge clk_i) begin : proc_src_pkt
    pkt_t v;
    int   v_cnt;
    v     = s_src_pkt;
    v_cnt = s_src_word_cnt;
    if (reset_i) begin
      v     = PKT_IDLE;
      v_cnt = 0;
    end else if (src_valid_o && src_ready_i) begin
      v_cnt = v_cnt + 1;
      if (src_sop_o && !src_eop_o)
        v = PKT_MULTI;
      else if (!src_sop_o && src_eop_o)
        v = PKT_IDLE;
      else if (src_sop_o && src_eop_o) begin
        v     = PKT_SINGLE;
        v_cnt = 0;
      end
    end
    s_src_pkt      <= v;
    s_src_word_cnt <= v_cnt;
  end

  // Reset is high on the first clock and stays low after it falls.
  assume property (@(posedge clk_i) first_cycle |-> reset_i);
  assume property (@(posedge clk_i) first_cycle |=> !reset_i);
  assume property (@(posedge clk_i) !reset_i |=> !reset_i);

  // Keep is full except on the last beat, and is a contiguous low-ones mask.
  assume property (@(posedge clk_i) !snk_tlast_i |-> (snk_tkeep_i == {c_KEEP_W{1'b1}}));
  assume property (@(posedge clk_i) $onehot(keep_oh));
  assume property (@(posedge clk_i) snk_tkeep_i != '0);

  assert property (@(posedge clk_i)
    !reset_i && (s_src_pkt == PKT_IDLE) && src_ready_i && src_valid_o |-> src_sop_o);
  assert property (@(posedge clk_i)
    !reset_i && (s_src_pkt == PKT_MULTI) && src_ready_i && src_valid_o |-> !src_sop_o);
  assert property (@(posedge clk_i)
    !reset_i && src_ready_i && src_valid_o && src_sop_o && src_eop_o |=> (s_src_pkt == PKT_SINGLE));
  assert property (@(posedge clk_i)
    !reset_i && src_eop_o && src_ready_i && src_valid_o |-> (int'(src_empty_o) < c_WORD_BYTES));

endmodule

bind axis_to_avst axis_to_avst_sva #(
  .g_DATA_WIDTH (g_DATA_WIDTH)
) axis_to_avst_sva_i (
  .clk_i        (clk_i),
  .reset_i      (reset_i),
  .snk_tready_o (snk_tready_o),
  .snk_tvalid_i (snk_tvalid_i),
  .snk_tlast_i  (snk_tlast_i),
  .snk_tkeep_i  (snk_tkeep_i),
  .snk_tdata_i  (snk_tdata_i),
  .src_ready_i  (src_ready_i),
  .src_valid_o  (src_valid_o),
  .src_sop_o    (src_sop_o),
  .src_eop_o    (src_eop_o),
  .src_empty_o  (src_empty_o),
  .src_data_o   (src_data_o)
);
