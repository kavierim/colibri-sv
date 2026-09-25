// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit pipeline_buffer_vu. `assume reset_i` names the reset.
// The two `assume always` directives constrain the environment.
module pipeline_buffer_sva #(
  parameter int g_DATA_WIDTH = 32
) (
  input logic                          clk_i,
  input logic                          reset_i,
  input logic [g_DATA_WIDTH-1:0]       snk_data_i,
  input logic                          snk_valid_i,
  input logic                          snk_ready_o,
  input logic [g_DATA_WIDTH-1:0]       src_data_o,
  input logic                          src_valid_o,
  input logic                          src_ready_i,
  input logic                          stall,
  input logic                          reg_valid,
  input logic                          skid_valid,
  input logic [g_DATA_WIDTH-1:0]       skid_data
);

  a_hold_when_stalled: assume property (@(posedge clk_i)
    (snk_valid_i && !snk_ready_o) |=> (snk_valid_i && (snk_data_i == $past(snk_data_i))));

  a_no_valid_after_reset: assume property (@(posedge clk_i)
    reset_i |=> !snk_valid_i);

  t_no_valid_after_reset: assert property (@(posedge clk_i)
    reset_i |=> (!src_valid_o && !stall && !reg_valid && !skid_valid));

  t_out_stable_backpressure: assert property (@(posedge clk_i)
    !reset_i && src_valid_o && !src_ready_i |=>
      (src_valid_o && (src_data_o == $past(src_data_o))));

  t_reg_read: assert property (@(posedge clk_i)
    (stall && src_ready_i) |=> !stall);

  t_no_data_drop: assert property (@(posedge clk_i)
    !reset_i && reg_valid && snk_ready_o && !src_ready_i |=>
      (stall && (skid_data == $past(snk_data_i))));

  t_valid_out: assert property (@(posedge clk_i)
    !reset_i && snk_valid_i && snk_ready_o |=> src_valid_o);

  t_consume_reg: assert property (@(posedge clk_i)
    !reset_i && !snk_valid_i && !skid_valid && src_ready_i |=> !reg_valid);

endmodule

bind pipeline_buffer pipeline_buffer_sva #(
  .g_DATA_WIDTH(g_DATA_WIDTH)
) u_pipeline_buffer_sva (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .snk_data_i(snk_data_i),
  .snk_valid_i(snk_valid_i),
  .snk_ready_o(snk_ready_o),
  .src_data_o(src_data_o),
  .src_valid_o(src_valid_o),
  .src_ready_i(src_ready_i),
  .stall(stall),
  .reg_valid(reg_valid),
  .skid_valid(skid_valid),
  .skid_data(skid_if.data)
);
