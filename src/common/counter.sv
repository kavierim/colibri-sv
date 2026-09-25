// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple Counter
// Some of the work was inspired by the PoC Library (https://github.com/VLSI-EDA/PoC)
// Release log:
// - 0.2 Modify g_MODULO behavior to avoid integer limits at 32 bits
// - 0.1 first release
//
// Style reference for later modules. See CONVENTIONS.md.

`timescale 1ns/1ps

module counter #(
  parameter int unsigned g_MODULO = 0,
  parameter int unsigned g_COUNTER_WIDTH = colibri_utils::log2ceil(int'(g_MODULO))
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic enable_i,
  output logic [((g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1)-1:0] value_o,
  output logic wraparound_o
);

  // g_MODULO 0 and g_COUNTER_WIDTH 0 is the VHDL default, whose port is a null
  // range. SV elaborates that unused default as 1 bit. Explicit widths >= 1
  // are unchanged.
  localparam int unsigned c_WIDTH = (g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1;

  logic [c_WIDTH-1:0] counter_int /* verilator public */ = '0;

  if (int'(g_COUNTER_WIDTH) < colibri_utils::log2ceil(int'(g_MODULO))) begin : gen_width_check
    $error("ERROR: counter width not sufficient for selected modulo");
  end

  assign value_o = counter_int;

  if (g_MODULO > 0) begin : gen_wrap
    assign wraparound_o = enable_i && (counter_int == c_WIDTH'(g_MODULO - 1));
  end else begin : gen_free
    assign wraparound_o = enable_i && (&counter_int);
  end

  always_ff @(posedge clk_i) begin : proc_cnt
    if (reset_i || wraparound_o)
      counter_int <= '0;
    else if (enable_i)
      counter_int <= counter_int + c_WIDTH'(1);
  end

endmodule
