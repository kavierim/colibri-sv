// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Pipeline buffer (two-stage fifo) to propagate back-pressure and register combinational paths.
// Use this for better performance and full decoupling, use skid buffer if low latency is needed.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module pipeline_buffer #(
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
  interface_t reg_if;
  interface_t skid_if /* verilator public */;
  logic       reg_valid  /* verilator public */ = 1'b0;
  logic       skid_valid /* verilator public */ = 1'b0;
  logic       stall      /* verilator public */ = 1'b1;

  always_ff @(posedge clk_i) begin : proc_skid
    if (reset_i) begin
      stall      <= 1'b0;
      reg_valid  <= 1'b0;
      skid_valid <= 1'b0;
    end else if (!stall) begin
      // Back-pressure: park the input in the skid register.
      if (!src_ready_i && reg_valid) begin
        skid_if    <= snk_if;
        skid_valid <= snk_valid_i;
        stall      <= 1'b1;
      end else begin
        reg_if    <= snk_if;
        reg_valid <= snk_valid_i;
      end
    end else if (src_ready_i || !reg_valid) begin
      // Move the skid register into the main register.
      reg_if    <= skid_if;
      reg_valid <= skid_valid;
      stall     <= 1'b0;
    end
  end

  assign snk_ready_o = ~stall;
  assign src_if      = reg_if;

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
  assign src_valid_o = reg_valid;

endmodule
