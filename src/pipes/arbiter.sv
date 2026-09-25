// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Round-robin arbiter. Inspired by https://github.com/chclau/arbiter_rr
// Grants one requester. The priority mask rotates after a grant is released.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module arbiter #(
  parameter int g_NUM_INPUTS = 4
) (
  input  logic                    clk_i,
  input  logic                    reset_i,
  input  logic [g_NUM_INPUTS-1:0] requests_i,
  output logic [g_NUM_INPUTS-1:0] grants_o
);

  localparam int c_DBL = 2 * g_NUM_INPUTS;

  logic [c_DBL-1:0]         double_req;
  logic [c_DBL-1:0]         double_gnt;
  // VHDL name `priority` is a SystemVerilog keyword.
  logic [g_NUM_INPUTS-1:0]  priority_q;
  logic [g_NUM_INPUTS-1:0]  reg_grants;
  logic [g_NUM_INPUTS-1:0]  cmb_grants;

  // Written every clock in the VHDL and never read.
  // verilator lint_off UNUSEDSIGNAL
  logic [g_NUM_INPUTS-1:0] last_reqs;
  // verilator lint_on UNUSEDSIGNAL

  assign double_req = {requests_i, requests_i};
  assign double_gnt = double_req & ~(double_req - c_DBL'(priority_q));

  always_ff @(posedge clk_i) begin : proc_clk_arbiter
    if (reset_i == 1'b1) begin
      reg_grants <= '0;
      last_reqs  <= '0;
      priority_q <= {{(g_NUM_INPUTS - 1){1'b0}}, 1'b1};
    end else begin
      last_reqs  <= requests_i;
      reg_grants <= cmb_grants;
      if ((|(reg_grants & requests_i)) == 1'b0) begin
        for (int i = 0; i < g_NUM_INPUTS; i++)
          priority_q[(i + 1) % g_NUM_INPUTS] <= priority_q[i];
      end
    end
  end

  always_comb begin : proc_cmb_arbiter
    cmb_grants = reg_grants;
    if ((|(reg_grants & requests_i)) == 1'b0)
      cmb_grants = double_gnt[g_NUM_INPUTS-1:0] | double_gnt[c_DBL-1 -: g_NUM_INPUTS];
  end

  assign grants_o = cmb_grants;

endmodule
// verilator lint_on MULTITOP
