// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit skid_buffer_vu. `assume reset_i` names the reset.
// The two `assume always` directives constrain the environment.
module skid_buffer_sva #(
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
  input logic                          reg_full,
  input logic [g_DATA_WIDTH-1:0]       reg_data
);

  // Data does not change while the pipeline stalls.
  a_hold_when_stalled: assume property (@(posedge clk_i)
    (snk_valid_i && !snk_ready_o) |=> (snk_valid_i && (snk_data_i == $past(snk_data_i))));

  // No valid in the clock after reset.
  a_no_valid_after_reset: assume property (@(posedge clk_i)
    reset_i |=> !snk_valid_i);

  // Output is not valid after reset and the register is empty.
  t_no_valid_after_reset: assert property (@(posedge clk_i)
    reset_i |=> (!src_valid_o && !reg_full));

  // Output does not change when backpressure is applied.
  t_out_stable_backpressure: assert property (@(posedge clk_i) disable iff (reset_i)
    (src_valid_o && !src_ready_i) |=> (src_valid_o && (src_data_o == $past(src_data_o))));

  // No data is dropped: a stalled accept lands in the skid register.
  t_no_data_drop: assert property (@(posedge clk_i) disable iff (reset_i)
    (snk_valid_i && snk_ready_o && src_valid_o && !src_ready_i) |=>
      (reg_full && (reg_data == $past(snk_data_i))));

  // Idle: a ready source mirrors valid on the next clock.
  t_idle: assert property (@(posedge clk_i) disable iff (reset_i)
    src_ready_i |=> (snk_valid_i == src_valid_o));

  // A ready read clears the register.
  t_reg_read: assert property (@(posedge clk_i)
    (reg_full && src_ready_i) |=> !reg_full);

endmodule

bind skid_buffer skid_buffer_sva #(
  .g_DATA_WIDTH(g_DATA_WIDTH)
) u_skid_buffer_sva (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .snk_data_i(snk_data_i),
  .snk_valid_i(snk_valid_i),
  .snk_ready_o(snk_ready_o),
  .src_data_o(src_data_o),
  .src_valid_o(src_valid_o),
  .src_ready_i(src_ready_i),
  .reg_full(reg_full),
  .reg_data(reg_if.data)
);
