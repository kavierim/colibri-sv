// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Translated from fv/packet/broadcaster.psl.
// The PSL fixes three outputs. The checker follows g_NUM_OUTPUTS so the bind
// matches the instance; the testbench uses 3, as the PSL does.

`timescale 1ns/1ps

module broadcaster_sva #(
  parameter int unsigned g_NUM_OUTPUTS = 3
) (
  input logic                          clk_i,
  input logic                          reset_i,
  input logic                          snk_sop_i,
  input logic                          snk_eop_i,
  input logic                          snk_valid_i,
  input logic                          snk_ready_o,
  input logic [g_NUM_OUTPUTS-1:0]      src_sop_o,
  input logic [g_NUM_OUTPUTS-1:0]      src_eop_o,
  input logic [g_NUM_OUTPUTS-1:0]      src_valid_o,
  input logic [g_NUM_OUTPUTS-1:0]      src_ready_i
);

  typedef enum logic [1:0] {
    PKT_IDLE   = 2'd0,
    PKT_SINGLE = 2'd1,
    PKT_MULTI  = 2'd2
  } pkt_t;

  pkt_t srcs_pkt = PKT_IDLE;
  pkt_t snks_arr [0:g_NUM_OUTPUTS-1];

  initial begin
    for (int i = 0; i < g_NUM_OUTPUTS; i++)
      snks_arr[i] = PKT_IDLE;
  end

  // First clock is in reset. Verilator 5.020 rejects a concurrent assert inside initial.
  logic rst_seen;
  initial rst_seen = 1'b0;
  always_ff @(posedge clk_i) rst_seen <= 1'b1;
  a_reset_start: assume property (@(posedge clk_i) !rst_seen |-> reset_i);

  always_ff @(posedge clk_i) begin : proc_snk_pkt
    if (reset_i) begin
      srcs_pkt <= PKT_IDLE;
    end else if (snk_valid_i && snk_ready_o) begin
      if (snk_sop_i && !snk_eop_i)
        srcs_pkt <= PKT_MULTI;
      else if (!snk_sop_i && snk_eop_i)
        srcs_pkt <= PKT_IDLE;
      else if (snk_sop_i && snk_eop_i)
        srcs_pkt <= PKT_SINGLE;
    end
  end

  always_ff @(posedge clk_i) begin : proc_src_pkt
    for (int i = 0; i < g_NUM_OUTPUTS; i++) begin
      if (reset_i) begin
        snks_arr[i] <= PKT_IDLE;
      end else if (src_valid_o[i] && src_ready_i[i]) begin
        if (src_sop_o[i] && !src_eop_o[i])
          snks_arr[i] <= PKT_MULTI;
        else if (!src_sop_o[i] && src_eop_o[i])
          snks_arr[i] <= PKT_IDLE;
        else if (src_sop_o[i] && src_eop_o[i])
          snks_arr[i] <= PKT_SINGLE;
      end
    end
  end

  a_snk_no_sop_in_multi: assume property (@(posedge clk_i)
    srcs_pkt == PKT_MULTI |-> !snk_sop_i);

  a_snk_no_valid_outside: assume property (@(posedge clk_i)
    (!snk_sop_i && srcs_pkt != PKT_MULTI) |-> !snk_valid_i);

`ifdef COLIBRI_FORMAL
  a_snk_no_ready_outside: assume property (@(posedge clk_i)
    (!snk_sop_i && srcs_pkt != PKT_MULTI) |-> !snk_ready_o);
`endif

  for (genvar gi = 0; gi < g_NUM_OUTPUTS; gi++) begin : gen_out
    a_valid_out_sop: assert property (@(posedge clk_i)
      (!reset_i && snks_arr[gi] == PKT_IDLE && src_ready_i[gi] && src_valid_o[gi])
      |-> src_sop_o[gi]);

    a_valid_out_multi: assert property (@(posedge clk_i)
      (!reset_i && snks_arr[gi] == PKT_MULTI && src_ready_i[gi] && src_valid_o[gi])
      |-> !src_sop_o[gi]);

    c_valid_out_single: cover property (@(posedge clk_i)
      src_ready_i[gi] && src_valid_o[gi] && src_sop_o[gi] && src_eop_o[gi]);
  end

endmodule

bind broadcaster broadcaster_sva #(
  .g_NUM_OUTPUTS (g_NUM_OUTPUTS)
) u_broadcaster_sva (
  .clk_i       (clk_i),
  .reset_i     (reset_i),
  .snk_sop_i   (snk_sop_i),
  .snk_eop_i   (snk_eop_i),
  .snk_valid_i (snk_valid_i),
  .snk_ready_o (snk_ready_o),
  .src_sop_o   (src_sop_o),
  .src_eop_o   (src_eop_o),
  .src_valid_o (src_valid_o),
  .src_ready_i (src_ready_i)
);
