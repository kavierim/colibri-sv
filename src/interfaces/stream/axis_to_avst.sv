// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// AXI Stream to Avalon ST adapter.
// AXI-Stream byte order is little-endian (first byte in the low bits). Partially
// empty words keep the valid bytes grouped at the low end.
// Release log:
// - 0.1 first release
// - 0.2 changed g_SWAP_ENDIANNESS for g_AVST_ENDIANNESS

`timescale 1ns/1ps

module axis_to_avst #(
  parameter int unsigned             g_DATA_WIDTH      = 32,
  // Avalon-Stream byte order. AXI-Stream is LITTLE by spec.
  parameter colibri_types::endian_t  g_AVST_ENDIANNESS = colibri_types::BIG,
  // Upstream leaves the skid buffer unimplemented.
  parameter bit                      g_ADD_REGISTERS   = 1'b1,
  localparam int c_KEEP_W  = colibri_utils::downto_width(int'(g_DATA_WIDTH) / 8),
  localparam int c_EMPTY_W = colibri_utils::downto_width(
    colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))
) (
  input  logic                    clk_i,
  input  logic                    reset_i,
  output logic                    snk_tready_o,
  input  logic                    snk_tvalid_i,
  input  logic                    snk_tlast_i,
  input  logic [c_KEEP_W-1:0]     snk_tkeep_i,
  input  logic [g_DATA_WIDTH-1:0] snk_tdata_i,
  input  logic                    src_ready_i,
  output logic                    src_valid_o,
  output logic                    src_sop_o,
  output logic                    src_eop_o,
  output logic [c_EMPTY_W-1:0]    src_empty_o,
  output logic [g_DATA_WIDTH-1:0] src_data_o
);

  logic last_eop;

  // g_ADD_REGISTERS is part of the entity and is unused upstream.
  // verilator lint_off UNUSEDSIGNAL
  logic unused_g_add_registers;
  assign unused_g_add_registers = g_ADD_REGISTERS;
  // verilator lint_on UNUSEDSIGNAL

  // Lowest set bit of (keep xor (keep >> 1)) wins, matching the VHDL downto loop.
  function automatic logic [c_EMPTY_W-1:0] keep_to_empty(input logic [c_KEEP_W-1:0] keep);
    logic [c_EMPTY_W-1:0] v_empty;
    logic [c_KEEP_W-1:0]  v_onehot;
    v_empty  = '0;
    if (keep == '0)
      $error("keep cannot be 0");
    v_onehot = keep ^ (keep >> 1);
    for (int i = c_KEEP_W - 1; i >= 0; i--) begin
      if (v_onehot[i])
        v_empty = c_EMPTY_W'(c_KEEP_W - 1 - i);
    end
    return v_empty;
  endfunction

  if (g_AVST_ENDIANNESS == colibri_types::BIG) begin : gen_endianness_data
    assign src_data_o = colibri_utils::bits#(int'(g_DATA_WIDTH))::swap_endianness(snk_tdata_i);
  end else begin : gen_endianness_little
    assign src_data_o = snk_tdata_i;
  end

  assign src_eop_o    = snk_tlast_i;
  assign src_valid_o  = snk_tvalid_i;
  assign snk_tready_o = src_ready_i;
  assign src_empty_o  = snk_tlast_i ? keep_to_empty(snk_tkeep_i) : '0;
  assign src_sop_o    = (last_eop && snk_tvalid_i) ? 1'b1 : 1'b0;

  always_ff @(posedge clk_i) begin : proc_sop_driver
    if (reset_i)
      last_eop <= 1'b1;
    else if (snk_tvalid_i && snk_tready_o)
      last_eop <= snk_tlast_i;
  end

endmodule
