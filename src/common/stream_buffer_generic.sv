// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple stream buffer with a generic type.
// Zero latency (skid) when g_REGISTER_DATAPATH is 0.
// One clock of latency (pipeline) when g_REGISTER_DATAPATH is 1.
// VHDL requires data_t (no default). logic [7:0] lets Verilator elaborate this module.

`timescale 1ns/1ps

// Entity files are extra tops next to wave0_elab.
// verilator lint_off MULTITOP
module stream_buffer_generic #(
  parameter type data_t             = logic [7:0],
  parameter bit  g_REGISTER_DATAPATH = 1'b0
) (
  input  logic  reset_i,
  input  logic  clk_i,
  input  data_t snk_data_i,
  input  logic  snk_valid_i,
  output logic  snk_ready_o,
  output data_t src_data_o,
  input  logic  src_ready_i,
  output logic  src_valid_o
);

  logic  snk_ready;
  data_t skid_data;

  if (!g_REGISTER_DATAPATH) begin : gen_buffer_style
    always_ff @(posedge clk_i) begin : proc_skid
      if (reset_i) begin
        snk_ready <= 1'b1;
      end else if (snk_ready) begin
        if (!src_ready_i && snk_valid_i) begin
          skid_data <= snk_data_i;
          snk_ready <= 1'b0;
        end
      end else if (src_ready_i) begin
        snk_ready <= 1'b1;
      end
    end

    assign src_data_o  = snk_ready ? snk_data_i : skid_data;
    assign src_valid_o = (!snk_ready && !reset_i) ? 1'b1 : (snk_valid_i && !reset_i);
  end else begin : gen_buffer_pipeline
    logic  reg_valid;
    logic  skid_valid;
    data_t reg_data;

    always_ff @(posedge clk_i) begin : proc_pipeline
      if (reset_i) begin
        snk_ready <= 1'b1;
      end else if (snk_ready) begin
        if (reg_valid && !src_ready_i) begin
          skid_data  <= snk_data_i;
          skid_valid <= snk_valid_i;
          snk_ready  <= 1'b0;
        end else begin
          reg_data  <= snk_data_i;
          reg_valid <= snk_valid_i;
        end
      end else if (!reg_valid || src_ready_i) begin
        reg_data  <= skid_data;
        reg_valid <= skid_valid;
        snk_ready <= 1'b1;
      end
    end

    assign src_data_o  = reg_data;
    assign src_valid_o = reg_valid;
  end

  assign snk_ready_o = snk_ready;

endmodule
