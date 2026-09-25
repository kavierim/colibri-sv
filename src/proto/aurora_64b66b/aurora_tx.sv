// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Aurora 64b/66b Transmitter.
// Simplex multi-lane Aurora 64b/66b transmitter chain (PMA/PCS):
// ENCODER -> SCRAMBLER -> GEARBOX
// Release log:
// - 0.1 first release
// - 0.2 add sub-entity register control in generics
// - 0.3 add multi-lane support
// - 0.4 vhdl common library integration
// - 0.4b Update to VHDL Style Guideline
// - 0.5 use only two clocks (removed the need of lane_clk), add generic lane width

`timescale 1ns/1ps

module aurora_tx #(
  parameter int unsigned g_N_LANES           = 1,
  parameter int unsigned g_LANE_WIDTH        = 32,
  parameter int unsigned g_GBX_BUF_SIZE      = 16 * colibri_aurora_const::c_AURORA_ENC_WIDTH,
  parameter bit          g_DISABLE_SCRAMBLER = 1'b0
) (
  input  logic snk_clk_i,
  input  logic snk_reset_i,
  input  logic src_clk_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic snk_valid_i,
  output logic snk_ready_o,
  input  logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] snk_data_i,
  input  logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] snk_empty_i,
  output logic [g_LANE_WIDTH-1:0] src_data_o [0:g_N_LANES-1],
  output logic [g_N_LANES-1:0]    src_valid_o,
  input  logic [g_N_LANES-1:0]    src_ready_i
);

  localparam int c_DATA_W        = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W         = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_GBX_BUF_WORDS = int'(g_GBX_BUF_SIZE) / int'(g_LANE_WIDTH);

  logic [c_ENC_W-1:0]   encoded_data [0:g_N_LANES-1];
  logic [c_ENC_W-1:0]   scrambled_data [0:g_N_LANES-1];
  logic [g_N_LANES-1:0] gbx_ready;
  logic [g_N_LANES-1:0] scrambler_ready;
  logic [g_N_LANES-1:0] encoded_valid;
  logic [g_N_LANES-1:0] scrambled_valid;

  aurora_st_encoder #(
    .g_N_LANES(g_N_LANES),
    .g_LANE_WIDTH(g_LANE_WIDTH)
  ) encoder_inst (
    .clk_i(snk_clk_i),
    .reset_i(snk_reset_i),
    .snk_sop_i(snk_sop_i),
    .snk_eop_i(snk_eop_i),
    .snk_valid_i(snk_valid_i),
    .snk_ready_o(snk_ready_o),
    .snk_data_i(snk_data_i),
    .snk_empty_i(snk_empty_i),
    .src_data_o(encoded_data),
    .src_ready_i(scrambler_ready),
    .src_valid_o(encoded_valid)
  );

  for (genvar i = 0; i < g_N_LANES; i++) begin : gen_n_lanes
    if (g_DISABLE_SCRAMBLER) begin : gen_scrambler
      assign scrambled_valid[i] = encoded_valid[i];
      assign scrambled_data[i]  = encoded_data[i];
      assign scrambler_ready[i] = gbx_ready[i];
    end else begin : gen_scrambler_en
      // VHDL connects the 64-bit payload and the 2-bit header as slices of one word.
      logic [c_DATA_W-1:0] lane_payload;
      logic [1:0]          lane_header;

      scrambler #(
        .g_DATA_WIDTH(c_DATA_W),
        .g_SCRAMBLER_POLY(colibri_poly::c_SCR_10GBASE)
      ) scrambler_inst (
        .clk_i(snk_clk_i),
        .reset_i(snk_reset_i),
        .snk_data_i(encoded_data[i][c_DATA_W-1:0]),
        .snk_valid_i(encoded_valid[i]),
        .snk_ready_o(scrambler_ready[i]),
        .src_valid_o(scrambled_valid[i]),
        .src_ready_i(gbx_ready[i]),
        .src_data_o(lane_payload)
      );

      // verilator lint_off PINMISSING
      meta_buffer #(
        .g_DATA_WIDTH(2)
      ) meta_buffer_inst (
        .clk_i(snk_clk_i),
        .reset_i(snk_reset_i),
        .snk_data_i(encoded_data[i][c_ENC_W-1:c_DATA_W]),
        .snk_valid_i(encoded_valid[i]),
        .src_ready_i(gbx_ready[i]),
        .src_data_o(lane_header)
      );
      // verilator lint_on PINMISSING

      assign scrambled_data[i] = {lane_header, lane_payload};
    end

    cc_gearbox #(
      .g_INPUT_WIDTH(c_ENC_W),
      .g_OUTPUT_WIDTH(int'(g_LANE_WIDTH)),
      .g_BUFFER_WORDS(c_GBX_BUF_WORDS)
    ) gbxdown_inst (
      .snk_clk_i(snk_clk_i),
      .snk_reset_i(snk_reset_i),
      .src_clk_i(src_clk_i),
      .snk_data_i(scrambled_data[i]),
      .snk_valid_i(scrambled_valid[i]),
      .snk_ready_o(gbx_ready[i]),
      .src_data_o(src_data_o[i]),
      .src_valid_o(src_valid_o[i]),
      .src_ready_i(src_ready_i[i])
    );
  end

endmodule
