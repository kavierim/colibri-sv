// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/packet/interleaver.psl.
// Ready-low assumes are formal-only; see header_add_sva.sv.

`timescale 1ns/1ps

module interleaver_sva #(
  parameter int unsigned g_NUM_INPUTS = 3
) (
  input logic                          clk_i,
  input logic                          reset_i,
  input logic [g_NUM_INPUTS-1:0]       snk_sop_i,
  input logic [g_NUM_INPUTS-1:0]       snk_eop_i,
  input logic [g_NUM_INPUTS-1:0]       snk_valid_i,
  input logic [g_NUM_INPUTS-1:0]       snk_ready_o,
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

  pkt_t srcs_arr [0:g_NUM_INPUTS-1];
  pkt_t snks_arr [0:g_NUM_INPUTS-1];

  initial begin
    for (int i = 0; i < g_NUM_INPUTS; i++) begin
      srcs_arr[i] = PKT_IDLE;
      snks_arr[i] = PKT_IDLE;
    end
  end

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

  always_ff @(posedge clk_i) begin : proc_srcs_pkt
    for (int i = 0; i < g_NUM_INPUTS; i++) begin
      if (reset_i) begin
        srcs_arr[i] <= PKT_IDLE;
      end else if (snk_valid_i[i] && snk_ready_o[i]) begin
        if (snk_sop_i[i] && !snk_eop_i[i])
          srcs_arr[i] <= PKT_MULTI;
        else if (!snk_sop_i[i] && snk_eop_i[i])
          srcs_arr[i] <= PKT_IDLE;
        else if (snk_sop_i[i] && snk_eop_i[i])
          srcs_arr[i] <= PKT_SINGLE;
      end
    end
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

  for (genvar gi = 0; gi < g_NUM_INPUTS; gi++) begin : gen_in
    a_no_sop_in_multi: assume property (@(posedge clk_i)
      srcs_arr[gi] == PKT_MULTI |-> !snk_sop_i[gi]);

    a_no_valid_outside: assume property (@(posedge clk_i)
      (!snk_sop_i[gi] && srcs_arr[gi] != PKT_MULTI) |-> !snk_valid_i[gi]);

`ifdef COLIBRI_FORMAL
    a_no_ready_outside: assume property (@(posedge clk_i)
      (!snk_sop_i[gi] && srcs_arr[gi] != PKT_MULTI) |-> !snk_ready_o[gi]);
`endif
  end

  a_only_one_src_active: assert property (@(posedge clk_i)
    !reset_i |-> $onehot0(snk_ready_o));

  for (genvar go = 0; go < g_NUM_INPUTS; go++) begin : gen_out
    a_valid_out_sop: assert property (@(posedge clk_i)
      (!reset_i && snks_arr[go] == PKT_IDLE && src_channel_o == c_CH_W'(go)
       && src_ready_i && src_valid_o) |-> src_sop_o);

    a_valid_out_multi: assert property (@(posedge clk_i)
      (!reset_i && snks_arr[go] == PKT_MULTI && src_channel_o == c_CH_W'(go)
       && src_ready_i && src_valid_o) |-> !src_sop_o);

    a_valid_out_single: assert property (@(posedge clk_i)
      (!reset_i && src_ready_i && src_valid_o && src_sop_o && src_eop_o
       && src_channel_o == c_CH_W'(go)) |=> (snks_arr[go] == PKT_SINGLE));
  end

endmodule

bind interleaver interleaver_sva #(
  .g_NUM_INPUTS (g_NUM_INPUTS)
) u_interleaver_sva (
  .clk_i         (clk_i),
  .reset_i       (reset_i),
  .snk_sop_i     (snk_sop_i),
  .snk_eop_i     (snk_eop_i),
  .snk_valid_i   (snk_valid_i),
  .snk_ready_o   (snk_ready_o),
  .src_sop_o     (src_sop_o),
  .src_eop_o     (src_eop_o),
  .src_valid_o   (src_valid_o),
  .src_ready_i   (src_ready_i),
  .src_channel_o (src_channel_o)
);
