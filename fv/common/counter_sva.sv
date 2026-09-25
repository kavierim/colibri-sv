// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit counter_vu. `assume reset_i` names the reset for the formal
// tool; it is not a constant-high constraint (that would make the
// reset-release checks vacuous).
module counter_sva #(
  parameter int unsigned g_MODULO        = 0,
  parameter int unsigned g_COUNTER_WIDTH = 1
) (
  input logic clk_i,
  input logic reset_i,
  input logic enable_i,
  input logic [((g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1)-1:0] counter_int,
  input logic [((g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1)-1:0] value_o,
  input logic wraparound_o
);

  localparam int unsigned c_WIDTH = (g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1;

  // prev(reset) and not reset -> counter, wrap and value are 0.
  t_valid_reset: assert property (@(posedge clk_i)
    $past(reset_i) && !reset_i |->
      (counter_int == '0) && (wraparound_o == 1'b0) && (value_o == '0));

  // Not counting holds the register.
  t_not_counting: assert property (@(posedge clk_i)
    !reset_i && !enable_i |=> $stable(counter_int));

  if (g_MODULO > 0) begin : gen_modulo
    // Counting steps by one until the last code.
    t_count: assert property (@(posedge clk_i)
      !reset_i && enable_i && (counter_int != c_WIDTH'(g_MODULO - 1)) |=>
        counter_int == c_WIDTH'($past(counter_int) + c_WIDTH'(1)));

    // The last code wraps, and wraparound_o was high in that cycle.
    t_wraparound: assert property (@(posedge clk_i)
      !reset_i && enable_i && (counter_int == c_WIDTH'(g_MODULO - 1)) |=>
        (counter_int == '0) && $past(wraparound_o));
  end

endmodule

bind counter counter_sva #(
  .g_MODULO(g_MODULO),
  .g_COUNTER_WIDTH(g_COUNTER_WIDTH)
) u_counter_sva (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .enable_i(enable_i),
  .counter_int(counter_int),
  .value_o(value_o),
  .wraparound_o(wraparound_o)
);
