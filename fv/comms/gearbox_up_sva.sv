// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// PSL gearbox_up.psl, bound to gearbox with g_INPUT_WIDTH=4 and g_OUTPUT_WIDTH=12.

`timescale 1ns/1ps

module gearbox_up_sva #(
  parameter int g_INPUT_WIDTH = 4,
  parameter int g_OUTPUT_WIDTH = 12
) (
  input logic                        clk_i,
  input logic                        reset_i,
  input logic [g_INPUT_WIDTH-1:0]    snk_data_i,
  input logic                        snk_valid_i,
  input logic                        snk_ready_o,
  input logic [g_OUTPUT_WIDTH-1:0]   src_data_o,
  input logic                        src_valid_o,
  input logic                        src_ready_i
);

  if ((g_INPUT_WIDTH == 4) && (g_OUTPUT_WIDTH == 12)) begin : gen_gearbox_up
    logic saw_clk = 1'b0;

    always @(posedge clk_i) begin
      saw_clk <= 1'b1;
    end

    // Initial reset of the DUT. PSL `assume reset_i` holds through the first clock.
    a_init_reset: assume property (@(posedge clk_i) !saw_clk |-> reset_i);

    // If valid, keep valid if not ready.
    a_snk_valid_hold: assume property (@(posedge clk_i)
      (!snk_ready_o && snk_valid_i) |=> snk_valid_i);

    // If not ready and valid, data should be stable.
    a_snk_data_hold: assume property (@(posedge clk_i)
      (!snk_ready_o && snk_valid_i) |=> $stable(snk_data_i));

    // If valid, keep it valid when not ready.
    t_stable_valid_not_ready: assert property (@(posedge clk_i)
      (!reset_i && !src_ready_i && src_valid_o) |=> (src_valid_o || reset_i));

    // If not ready and valid, data should be stable.
    t_stable_data: assert property (@(posedge clk_i)
      (!reset_i && !src_ready_i && src_valid_o) |=> ($stable(src_data_o) || reset_i));

    // Verify reset state.
    t_valid_reset: assert property (@(posedge clk_i)
      (saw_clk && $past(reset_i) && !reset_i) |->
      (snk_ready_o && !src_valid_o && (src_data_o == '0)));
  end

endmodule

bind gearbox gearbox_up_sva #(
  .g_INPUT_WIDTH(g_INPUT_WIDTH),
  .g_OUTPUT_WIDTH(g_OUTPUT_WIDTH)
) gearbox_up_sva_i (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .snk_data_i(snk_data_i),
  .snk_valid_i(snk_valid_i),
  .snk_ready_o(snk_ready_o),
  .src_data_o(src_data_o),
  .src_valid_o(src_valid_o),
  .src_ready_i(src_ready_i)
);
