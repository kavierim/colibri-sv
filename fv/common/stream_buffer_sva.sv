// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit stream_buffer_vu. `assume reset_i` names the reset.
// `eventually!` is unbounded liveness; Verilator checks the same safety
// intent over the latency of this buffer.
module stream_buffer_sva #(
  parameter int g_DATA_WIDTH = 8
) (
  input logic                                                      clk_i,
  input logic                                                      reset_i,
  input logic                                                      snk_valid_i,
  input logic                                                      snk_ready_o,
  input logic                                                      src_valid_o,
  input logic                                                      src_ready_i,
  input logic [colibri_utils::downto_width(g_DATA_WIDTH)-1:0]      skid_data
);

  // After reset is released the sink is ready.
  t_reset_state: assert property (@(posedge clk_i)
    reset_i |=> (snk_ready_o == 1'b1));

  // A stalled buffer does not overwrite the skid register.
  t_buffer_stable: assert property (@(posedge clk_i) disable iff (reset_i)
    (snk_ready_o == 1'b0) |=> $stable(skid_data));

  // snk_valid |-> eventually src_valid, aborted by reset.
  // Bounded to four clocks: fail if src_valid stays low the whole window.
  // Same-cycle src_valid satisfies the check.
  t_data_pass: assert property (@(posedge clk_i) disable iff (reset_i)
    ($past(snk_valid_i && !reset_i, 4) &&
     $past(!reset_i, 3) && $past(!reset_i, 2) && $past(!reset_i, 1) &&
     ($past(src_valid_o, 4) == 1'b0) && ($past(src_valid_o, 3) == 1'b0) &&
     ($past(src_valid_o, 2) == 1'b0) && ($past(src_valid_o, 1) == 1'b0) &&
     (src_valid_o == 1'b0)) |-> 1'b0);

  c_normal: cover property (@(posedge clk_i)
    snk_valid_i && src_ready_i && src_valid_o && snk_ready_o);

  c_backpressure_register: cover property (@(posedge clk_i)
    snk_valid_i && !src_ready_i && src_valid_o && snk_ready_o);

  c_backpressure_propagate: cover property (@(posedge clk_i)
    snk_valid_i && !src_ready_i && !snk_ready_o);

  c_backpressure_clear: cover property (@(posedge clk_i)
    snk_valid_i && src_ready_i && src_valid_o && !snk_ready_o);

endmodule

bind stream_buffer stream_buffer_sva #(
  .g_DATA_WIDTH(g_DATA_WIDTH)
) u_stream_buffer_sva (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .snk_valid_i(snk_valid_i),
  .snk_ready_o(snk_ready_o),
  .src_valid_o(src_valid_o),
  .src_ready_i(src_ready_i),
  .skid_data(skid_data)
);
