// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Aurora 64b/66b Receiver.
// Simplex multi-lane Aurora 64b/66b receiver chain (PMA/PCS):
// GEARBOX -> DESCRAMBLER -> BIT_SHIFT_FSM -> CHANNEL_BONDING -> DECODER
// changelog:
// - 0.1 first release
// - 0.2 add sub-entity register control in generics
// - 0.3 add multi-lane support
// - 0.3b: update to lhcb vhdl style guideline

`timescale 1ns/1ps

module aurora_rx #(
  parameter int unsigned g_N_LANES             = 1,
  parameter int unsigned g_LANE_WIDTH          = 32,
  parameter int unsigned g_GBX_BUF_SIZE        = colibri_aurora_const::c_AURORA_ENC_WIDTH * 16,
  parameter bit          g_DISABLE_DESCRAMBLER = 1'b0,
  parameter bit          g_USE_OPTIMIZED_GBX   = 1'b1
) (
  input  logic snk_clk_i,
  input  logic src_clk_i,
  input  logic src_reset_i,
  input  logic [g_N_LANES-1:0] snk_valid_i,
  input  logic [g_LANE_WIDTH-1:0] snk_data_i [0:g_N_LANES-1],
  output logic src_sop_o,
  output logic src_eop_o,
  output logic src_valid_o,
  output logic src_error_o,
  output logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] src_data_o,
  output logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] src_empty_o,
  output logic src_link_up_o
);

  localparam int c_DATA_W        = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W         = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_GBX_BUF_WORDS = int'(g_GBX_BUF_SIZE) / int'(g_LANE_WIDTH);

  logic [c_ENC_W-1:0]   slip_data [0:g_N_LANES-1];
  logic [c_ENC_W-1:0]   descrambled_data [0:g_N_LANES-1];
  logic [c_ENC_W-1:0]   bond_data [0:g_N_LANES-1];
  logic [g_N_LANES-1:0] slip_valid;
  logic [g_N_LANES-1:0] descrambled_valid;
  logic [g_N_LANES-1:0] bond_valid;
  logic [g_N_LANES-1:0] sync_done;
  logic [g_N_LANES-1:0] slip;
  logic                 bond_done;
  logic                 snk_reset;

  synchro_reset #(
    .g_IN_POLARITY(1'b1),
    .g_OUT_POLARITY(1'b1),
    .g_DURATION(1)
  ) u_synchro_reset (
    .clk_i(snk_clk_i),
    .reset_i(src_reset_i),
    .reset_o(snk_reset)
  );

  // Same reduction as bits#(W)::andvec. Specialising bits at g_N_LANES elaborates
  // swap_endianness for a width that is not a multiple of 8, which Verilator
  // flags as SELRANGE inside colibri_utils.
  assign src_link_up_o = (&(sync_done & snk_valid_i)) & bond_done;

  for (genvar i = 0; i < g_N_LANES; i++) begin : gen_n_lanes
    if (g_USE_OPTIMIZED_GBX) begin : gen_opt_gbx
      cc_gearbox_up #(
        .g_INPUT_WIDTH(g_LANE_WIDTH),
        .g_OUTPUT_WIDTH(c_ENC_W),
        .g_BUFFER_WORDS(c_GBX_BUF_WORDS)
      ) gbxup_opt_inst (
        .snk_clk_i(snk_clk_i),
        .src_clk_i(src_clk_i),
        .snk_reset_i(snk_reset),
        .slip_i(slip[i]),
        .snk_data_i(snk_data_i[i]),
        .snk_valid_i(snk_valid_i[i]),
        .src_data_o(slip_data[i]),
        .src_valid_o(slip_valid[i])
      );
    end else begin : gen_plain_gbx
      logic [c_ENC_W-1:0] gearbox_data;
      logic               gearbox_valid;

      // verilator lint_off PINMISSING
      cc_gearbox #(
        .g_INPUT_WIDTH(int'(g_LANE_WIDTH)),
        .g_OUTPUT_WIDTH(c_ENC_W),
        .g_BUFFER_WORDS(c_GBX_BUF_WORDS)
      ) gbxup_inst (
        .snk_clk_i(snk_clk_i),
        .src_clk_i(src_clk_i),
        .snk_reset_i(snk_reset),
        .snk_data_i(snk_data_i[i]),
        .snk_valid_i(snk_valid_i[i]),
        .src_data_o(gearbox_data),
        .src_valid_o(gearbox_valid),
        .src_ready_i(1'b1)
      );

      slip_buffer #(
        .g_DATA_WIDTH(c_ENC_W)
      ) slip_buffer_inst (
        .clk_i(src_clk_i),
        .reset_i(src_reset_i),
        .slip_i(slip[i]),
        .snk_data_i(gearbox_data),
        .snk_valid_i(gearbox_valid),
        .src_valid_o(slip_valid[i]),
        .src_ready_i(1'b1),
        .src_data_o(slip_data[i])
      );
      // verilator lint_on PINMISSING
    end

    if (g_DISABLE_DESCRAMBLER) begin : gen_descrambler
      assign descrambled_valid = slip_valid;
      assign descrambled_data  = slip_data;
    end else begin : gen_descrambler_en
      logic [c_DATA_W-1:0] lane_payload;
      logic [1:0]          lane_header;

      // verilator lint_off PINMISSING
      descrambler #(
        .g_DATA_WIDTH(c_DATA_W),
        .g_SCRAMBLER_POLY(colibri_poly::c_SCR_10GBASE)
      ) descrambler_inst (
        .clk_i(src_clk_i),
        .reset_i(src_reset_i),
        .snk_data_i(slip_data[i][c_DATA_W-1:0]),
        .snk_valid_i(slip_valid[i]),
        .src_valid_o(descrambled_valid[i]),
        .src_ready_i(1'b1),
        .src_data_o(lane_payload)
      );

      meta_buffer #(
        .g_DATA_WIDTH(2)
      ) meta_buffer_inst (
        .clk_i(src_clk_i),
        .reset_i(src_reset_i),
        .snk_data_i(slip_data[i][c_ENC_W-1:c_DATA_W]),
        .snk_valid_i(slip_valid[i]),
        .src_ready_i(1'b1),
        .src_data_o(lane_header)
      );
      // verilator lint_on PINMISSING

      assign descrambled_data[i] = {lane_header, lane_payload};
    end

    block_sync_fsm bs_fsm_inst (
      .clk_i(src_clk_i),
      .reset_i(src_reset_i),
      .snk_meta_i(descrambled_data[i][c_ENC_W-1:c_ENC_W-2]),
      .snk_valid_i(descrambled_valid[i]),
      .snk_slip_o(slip[i]),
      .src_sync_o(sync_done[i])
    );
  end

  if (g_N_LANES > 1) begin : gen_bond
    channel_bond #(
      .g_N_LANES(g_N_LANES),
      .g_BUF_SIZE(32),
      .g_REGISTER_OUT(1'b1)
    ) ch_bond_inst (
      .clk_i(src_clk_i),
      .reset_i(src_reset_i),
      .snk_data_i(descrambled_data),
      .snk_valid_i(descrambled_valid),
      .src_data_o(bond_data),
      .src_valid_o(bond_valid),
      .src_bond_o(bond_done)
    );
  end else begin : gen_bond_bypass
    assign bond_data  = descrambled_data;
    assign bond_valid = descrambled_valid;
    assign bond_done  = 1'b1;
  end

  // verilator lint_off PINMISSING
  aurora_st_decoder #(
    .g_N_LANES(g_N_LANES),
    .g_LANE_WIDTH(g_LANE_WIDTH)
  ) decoder_inst (
    .clk_i(src_clk_i),
    .reset_i(src_reset_i),
    .snk_data_i(bond_data),
    .snk_valid_i(&bond_valid),
    .snk_link_up_i(src_link_up_o),
    .src_sop_o(src_sop_o),
    .src_eop_o(src_eop_o),
    .src_valid_o(src_valid_o),
    .src_error_o(src_error_o),
    .src_data_o(src_data_o),
    .src_empty_o(src_empty_o)
  );
  // verilator lint_on PINMISSING

endmodule
