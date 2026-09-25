// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit debouncer_vu, written against the debouncer_fv generics
// (100 ns debounce, 10 ns clock): 12 stable cycles copy the input, and
// 1..11 stable cycles followed by a change leave the output stable.
// s_val is PSL anyconst. Each possible constant is checked.
// `assume reset_i` names the reset for the formal tool.
module debouncer_sva #(
  parameter int g_WIDTH = 1
) (
  input logic                  clk_i,
  input logic                  reset_i,
  input logic [g_WIDTH-1:0]    data_i,
  input logic [g_WIDTH-1:0]    data_o
);

  for (genvar gi = 0; gi < (1 << g_WIDTH); gi++) begin : gen_val
    localparam logic [g_WIDTH-1:0] s_val = g_WIDTH'(gi);

    logic match_s;
    logic change_s;
    // Previous matches. Bit 0 is the last clock; bit 10 is eleven clocks ago.
    logic [10:0] match_hist = '0;

    assign match_s  = !reset_i && (data_i == s_val);
    assign change_s = !reset_i && (data_i != s_val);

    always_ff @(posedge clk_i) begin
      match_hist <= {match_hist[9:0], match_s};
    end

    // (!reset && data == s_val)[*12] |=> data_o == s_val
    // The current sample plus the previous eleven are the repetition.
    t_stable_in: assert property (@(posedge clk_i)
      (match_s && (&match_hist)) |=> (data_o == s_val));

    // (match)[*1 to 11] ##1 change |=> stable(data_o).
    // Every length in that range shares this consequent. A one-cycle match
    // before the change covers the range, and the eleven-cycle form keeps
    // the PSL upper bound explicit.
    t_unsstable_in: assert property (@(posedge clk_i)
      (change_s && match_hist[0]) |=> $stable(data_o));

    t_unsstable_in_11: assert property (@(posedge clk_i)
      (change_s && (&match_hist)) |=> $stable(data_o));
  end

endmodule

bind debouncer debouncer_sva #(
  .g_WIDTH($bits(data_i))
) u_debouncer_sva (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .data_i(data_i),
  .data_o(data_o)
);
