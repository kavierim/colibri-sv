// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Clock domain boundary synchronizer (legacy version).
// Synchronizes a vector across a clock domain. g_NUM_STAGES is at least 2.
// VHDL requires g_DATA_LENGTH (no default). Default 1 lets Verilator elaborate this module.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module synchro #(
  parameter int                       g_DATA_LENGTH = 1,
  parameter logic [g_DATA_LENGTH-1:0] g_INIT_VALUE  = '0,
  parameter int                       g_NUM_STAGES  = 2
) (
  input  logic                     clk_i,
  input  logic                     reset_i,
  input  logic [g_DATA_LENGTH-1:0] data_i,
  output logic [g_DATA_LENGTH-1:0] data_o
);

  // CDC attributes for ALTERA/INTEL and XILINX/AMD, matching the VHDL.
  (* preserve, async_reg, dont_touch,
     altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  logic [g_DATA_LENGTH-1:0] sync_chain [0:g_NUM_STAGES-1] = '{default: g_INIT_VALUE};

  if (g_DATA_LENGTH < 1) begin : gen_length_check
    $error("ERROR: g_DATA_LENGTH must be at least 1");
  end
  if (g_NUM_STAGES < 2) begin : gen_stages_check
    $error("ERROR: g_NUM_STAGES must be at least 2");
  end

  assign data_o = sync_chain[g_NUM_STAGES-1];

  // Shifts the register chain every destination clock cycle.
  always_ff @(posedge clk_i) begin : proc_sync
    if (reset_i) begin
      sync_chain <= '{default: g_INIT_VALUE};
    end else begin
      sync_chain[0] <= data_i;
      for (int i = 0; i <= (g_NUM_STAGES - 2); i++)
        sync_chain[i + 1] <= sync_chain[i];
    end
  end

endmodule
