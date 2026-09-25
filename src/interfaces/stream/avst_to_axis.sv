// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Avalon ST to AXI Stream adapter.
// Release log:
// - 0.1 first release
// - 0.2 changed g_SWAP_ENDIANNESS for g_AVST_ENDIANNESS

`timescale 1ns/1ps

module avst_to_axis #(
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
  output logic                    snk_ready_o,
  input  logic                    snk_valid_i,
  input  logic                    snk_sop_i,
  input  logic                    snk_eop_i,
  input  logic [c_EMPTY_W-1:0]    snk_empty_i,
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic                    src_tready_i,
  output logic                    src_tvalid_o,
  output logic                    src_tlast_o,
  output logic [c_KEEP_W-1:0]     src_tkeep_o,
  output logic [g_DATA_WIDTH-1:0] src_tdata_o
);

  // clk_i, reset_i, snk_sop_i and g_ADD_REGISTERS are entity ports/generics
  // that the VHDL architecture does not read.
  // verilator lint_off UNUSEDSIGNAL
  logic unused_inputs;
  assign unused_inputs = clk_i ^ reset_i ^ snk_sop_i ^ g_ADD_REGISTERS;
  // verilator lint_on UNUSEDSIGNAL

  function automatic logic [c_KEEP_W-1:0] empty_to_keep(input logic [c_EMPTY_W-1:0] empty);
    logic [c_KEEP_W-1:0] v_tkeep;
    for (int i = 0; i < c_KEEP_W; i++) begin
      if (i < c_KEEP_W - int'(empty))
        v_tkeep[i] = 1'b1;
      else
        v_tkeep[i] = 1'b0;
    end
    return v_tkeep;
  endfunction

  if (g_AVST_ENDIANNESS == colibri_types::BIG) begin : gen_endianness_data
    assign src_tdata_o = colibri_utils::bits#(int'(g_DATA_WIDTH))::swap_endianness(snk_data_i);
  end else begin : gen_endianness_little
    assign src_tdata_o = snk_data_i;
  end

  assign src_tlast_o  = snk_eop_i;
  assign src_tvalid_o = snk_valid_i;
  assign snk_ready_o  = src_tready_i;
  assign src_tkeep_o  = (snk_eop_i && (snk_empty_i != '0))
                        ? empty_to_keep(snk_empty_i)
                        : {c_KEEP_W{1'b1}};

endmodule
