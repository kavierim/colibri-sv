// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Formal wrapper from fv/common/utils_fv.vhdl. count_ones is combinational.
module utils_fv (
  input  logic        clk_i,
  input  logic        reset_i,
  input  logic [63:0] count_ones_i,
  output int          count_ones_o
);

  always_ff @(posedge clk_i) begin : proc_main_clk
    if (reset_i) begin
    end
  end

  assign count_ones_o = colibri_utils::bits#(64)::count_ones(count_ones_i);

endmodule

// PSL vunit utils_vu. `assume reset_i` names the reset; the check itself
// is the popcount equality on the default clock.
module utils_sva (
  input logic        clk_i,
  input logic        reset_i,
  input logic [63:0] count_ones_i,
  input int          count_ones_o
);

  int s_cntones;

  always_comb begin
    s_cntones = 0;
    for (int i = 0; i < 64; i++) begin
      if (count_ones_i[i])
        s_cntones = s_cntones + 1;
    end
  end

  t_check_count_ones: assert property (@(posedge clk_i)
    count_ones_o == s_cntones);

endmodule

bind utils_fv utils_sva u_utils_sva (
  .clk_i(clk_i),
  .reset_i(reset_i),
  .count_ones_i(count_ones_i),
  .count_ones_o(count_ones_o)
);
