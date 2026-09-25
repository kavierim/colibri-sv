// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Generic clock domain boundary synchronizer.
// Synchronizes an arbitrary data type across a clock domain.
// g_NUM_STAGES is at least 2.
// VHDL requires data_t and g_INIT_VALUE. The defaults exist so Verilator can elaborate this module.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module synchro_generic #(
  parameter type data_t         = logic [7:0],
  // Untyped: Verilator locks `parameter data_t` to the default type's width.
  // VHDL requires g_INIT_VALUE; 8'h00 matches the default data_t for elaboration.
  parameter g_INIT_VALUE        = 8'h00,
  parameter int g_NUM_STAGES    = 2
) (
  input  logic  clk_i,
  input  logic  reset_i,
  input  data_t data_i,
  output data_t data_o
);

  // CDC attributes for ALTERA/INTEL and XILINX/AMD, matching the VHDL.
  // dont_touch is not applied on this entity.
  (* preserve, async_reg,
     altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  localparam data_t c_INIT_VALUE = data_t'(g_INIT_VALUE);

  data_t sync_chain [0:g_NUM_STAGES-1] = '{default: c_INIT_VALUE};

  if (g_NUM_STAGES < 2) begin : gen_stages_check
    $error("ERROR: g_NUM_STAGES must be at least 2");
  end

  assign data_o = sync_chain[g_NUM_STAGES-1];

  // Shifts the register chain every destination clock cycle.
  always_ff @(posedge clk_i) begin : proc_sync
    if (reset_i) begin
      sync_chain <= '{default: c_INIT_VALUE};
    end else begin
      sync_chain[0] <= data_i;
      for (int i = 0; i <= (g_NUM_STAGES - 2); i++)
        sync_chain[i + 1] <= sync_chain[i];
    end
  end

endmodule
