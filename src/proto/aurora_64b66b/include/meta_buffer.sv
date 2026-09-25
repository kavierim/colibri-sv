// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Metadata propagation buffer.
// Buffer to propagate metadata in pipelined streams.
// changelog:
// - 0.1: initial release

`timescale 1ns/1ps

module meta_buffer #(
  parameter int unsigned g_DATA_WIDTH = 2
) (
  input  logic                          clk_i,
  input  logic                          reset_i,
  input  logic [g_DATA_WIDTH-1:0]       snk_data_i,
  input  logic                          snk_valid_i,
  output logic                          snk_ready_o,
  output logic                          src_valid_o,
  input  logic                          src_ready_i,
  output logic [g_DATA_WIDTH-1:0]       src_data_o
);

  logic                    tmpo_valid;
  logic [g_DATA_WIDTH-1:0] tmpo_data;
  logic                    reg_valid;
  logic                    cmb_valid;
  logic [g_DATA_WIDTH-1:0] reg_data;

  assign snk_ready_o = src_ready_i;

  always_ff @(posedge clk_i) begin : proc_reg_copy
    if (reset_i) begin
      tmpo_valid <= 1'b0;
      tmpo_data  <= '0;
    end else begin
      tmpo_valid <= snk_valid_i;
      tmpo_data  <= snk_data_i;
    end
  end

  always_ff @(posedge clk_i) begin : proc_register_output
    if (reset_i) begin
      reg_valid <= 1'b0;
    end else begin
      if (!src_ready_i && !reg_valid) begin
        reg_valid <= tmpo_valid;
        reg_data  <= tmpo_data;
      end
      if (src_ready_i && reg_valid)
        reg_valid <= 1'b0;
    end
  end

  assign src_data_o  = reg_valid ? reg_data : tmpo_data;
  assign cmb_valid   = tmpo_valid | reg_valid;
  assign src_valid_o = cmb_valid;

endmodule
