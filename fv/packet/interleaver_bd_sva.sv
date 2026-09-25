// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/packet/interleaver_bd.psl.
// Packet-boundary checks apply when g_INTERLEAVE_WORDS is 0. Word mode may
// change channel on every beat, so those asserts are generated only for the
// packet-boundary configuration. The shared protocol checks live in
// interleaver_sva.sv, which is the translation of interleaver.psl. This file
// is the extra boundary layer from interleaver_bd.psl.

`timescale 1ns/1ps

module interleaver_bd_sva #(
  parameter int unsigned g_NUM_INPUTS       = 3,
  parameter bit          g_INTERLEAVE_WORDS = 1'b0
) (
  input logic                          clk_i,
  input logic                          reset_i,
  input logic                          src_sop_o,
  input logic                          src_eop_o,
  input logic                          src_valid_o,
  input logic                          src_ready_i,
  input logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_INPUTS)))-1:0] src_channel_o
);

  localparam int c_CH_W = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_INPUTS)));

  typedef enum logic [1:0] {
    PKT_IDLE   = 2'd0,
    PKT_SINGLE = 2'd1,
    PKT_MULTI  = 2'd2
  } pkt_t;

  pkt_t snks_arr [0:g_NUM_INPUTS-1];

  initial begin
    for (int i = 0; i < g_NUM_INPUTS; i++)
      snks_arr[i] = PKT_IDLE;
  end

  always_ff @(posedge clk_i) begin : proc_snks_pkt
    for (int i = 0; i < g_NUM_INPUTS; i++) begin
      if (reset_i) begin
        snks_arr[i] <= PKT_IDLE;
      end else if (src_channel_o == c_CH_W'(i) && src_valid_o && src_ready_i) begin
        if (src_sop_o && !src_eop_o)
          snks_arr[i] <= PKT_MULTI;
        else if (!src_sop_o && src_eop_o)
          snks_arr[i] <= PKT_IDLE;
        else if (src_sop_o && src_eop_o)
          snks_arr[i] <= PKT_SINGLE;
      end
    end
  end

  if (!g_INTERLEAVE_WORDS) begin : gen_boundaries
    for (genvar go = 0; go < g_NUM_INPUTS; go++) begin : gen_ch
      a_pkt_boundaries: assert property (@(posedge clk_i)
        (!reset_i && snks_arr[go] == PKT_MULTI) |-> (src_channel_o == $past(src_channel_o)));
    end
  end

endmodule

bind interleaver interleaver_bd_sva #(
  .g_NUM_INPUTS       (g_NUM_INPUTS),
  .g_INTERLEAVE_WORDS (g_INTERLEAVE_WORDS)
) u_interleaver_bd_sva (
  .clk_i         (clk_i),
  .reset_i       (reset_i),
  .src_sop_o     (src_sop_o),
  .src_eop_o     (src_eop_o),
  .src_valid_o   (src_valid_o),
  .src_ready_i   (src_ready_i),
  .src_channel_o (src_channel_o)
);
