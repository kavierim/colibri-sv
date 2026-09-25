// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Skid buffer to propagate back-pressure.
// Use this if low latency is needed, use pipeline buffer for better performance and full decoupling.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module skid_buffer #(
  parameter int g_DATA_WIDTH = 32
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  // Integer division, matching the VHDL. downto_width turns a null range into 1 bit.
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i,
  input  logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] snk_keep_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic snk_valid_i,
  output logic snk_ready_o,
  output logic [g_DATA_WIDTH-1:0] src_data_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o,
  output logic [colibri_utils::downto_width(g_DATA_WIDTH / 8)-1:0] src_keep_o,
  output logic src_sop_o,
  output logic src_eop_o,
  output logic src_valid_o,
  input  logic src_ready_i
);

  localparam int c_EMPTY_W = $bits(snk_empty_i);
  localparam int c_KEEP_W  = $bits(snk_keep_i);

  typedef struct packed {
    logic [g_DATA_WIDTH-1:0] data;
    logic [c_EMPTY_W-1:0]    empty;
    logic [c_KEEP_W-1:0]     keep;
    logic                    sop;
    logic                    eop;
  } interface_t;

  interface_t snk_if;
  interface_t src_if;
  interface_t reg_if /* verilator public */;
  logic       reg_full /* verilator public */ = 1'b1; // force not ready when reset

  always_ff @(posedge clk_i) begin : proc_skid
    if (reset_i) begin
      reg_full <= 1'b0;
    end else if (!reg_full) begin
      // Back-pressure: register the input.
      if (!src_ready_i && snk_valid_i) begin
        reg_if   <= snk_if;
        reg_full <= 1'b1;
      end
    end else if (src_ready_i) begin
      reg_full <= 1'b0;
    end
  end

  assign src_if      = reg_full ? reg_if : snk_if;
  assign src_valid_o = (reg_full && !reset_i) ? 1'b1 : (snk_valid_i && snk_ready_o && !reset_i);
  assign snk_ready_o = ~reg_full;

  assign snk_if.data  = snk_data_i;
  assign snk_if.empty = snk_empty_i;
  assign snk_if.keep  = snk_keep_i;
  assign snk_if.sop   = snk_sop_i;
  assign snk_if.eop   = snk_eop_i;

  assign src_data_o  = src_if.data;
  assign src_empty_o = src_if.empty;
  assign src_keep_o  = src_if.keep;
  assign src_sop_o   = src_if.sop;
  assign src_eop_o   = src_if.eop;

endmodule
