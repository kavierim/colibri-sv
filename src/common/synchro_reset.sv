// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Reset signal synchronizer.
// Synchronizes an asynchronous reset into the destination clock domain.
// g_DURATION is how many destination clocks the output reset stays asserted
// after the input reset is released.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module synchro_reset #(
  parameter logic g_IN_POLARITY  = 1'b1,
  parameter logic g_OUT_POLARITY = 1'b1,
  parameter int   g_DURATION     = 1
) (
  input  logic clk_i,
  input  logic reset_i,
  output logic reset_o
);

  // Chain is (g_DURATION downto 0): g_DURATION + 1 flip-flops.
  localparam int c_CHAIN_W = g_DURATION + 1;

  // CDC attributes for ALTERA/INTEL and XILINX/AMD, matching the VHDL.
  (* preserve, async_reg, dont_touch,
     altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  logic [c_CHAIN_W-1:0] sync_chain = {c_CHAIN_W{~g_OUT_POLARITY}};

  if (g_DURATION < 1) begin : gen_duration_check
    $error("ERROR: g_DURATION must be at least 1");
  end

  assign reset_o = sync_chain[c_CHAIN_W-1];

  // Async reset, then a synchronous shift. Split by input polarity so the
  // sensitivity edge matches reset_i == g_IN_POLARITY.
  if (g_IN_POLARITY == 1'b1) begin : gen_async_high
    always_ff @(posedge clk_i or posedge reset_i) begin : proc_sync
      if (reset_i)
        sync_chain <= {c_CHAIN_W{g_OUT_POLARITY}};
      else
        sync_chain <= {sync_chain[c_CHAIN_W-2:0], ~g_OUT_POLARITY};
    end
  end else begin : gen_async_low
    always_ff @(posedge clk_i or negedge reset_i) begin : proc_sync
      if (!reset_i)
        sync_chain <= {c_CHAIN_W{g_OUT_POLARITY}};
      else
        sync_chain <= {sync_chain[c_CHAIN_W-2:0], ~g_OUT_POLARITY};
    end
  end

endmodule
