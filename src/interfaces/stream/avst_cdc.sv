// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Avalon-ST simple clock domain crossing.

`timescale 1ns/1ps

// Library modules are tops alongside wave0_elab until a later wave instantiates them.
// verilator lint_off MULTITOP
module avst_cdc #(
  parameter int unsigned g_DATA_WIDTH = 16,
  // VHDL constrains empty to log2ceil(g_DATA_WIDTH), not avst_empty_width.
  localparam int c_EMPTY_W = colibri_utils::downto_width(
    colibri_utils::log2ceil(int'(g_DATA_WIDTH)))
) (
  input  logic                     reset_i,
  input  logic                     snk_clk_i,
  input  logic                     src_clk_i,
  output logic                     snk_ready_o,
  input  logic                     snk_valid_i,
  input  logic                     snk_sop_i,
  input  logic                     snk_eop_i,
  input  logic [c_EMPTY_W-1:0]     snk_empty_i,
  input  logic [g_DATA_WIDTH-1:0]  snk_data_i,
  input  logic                     src_ready_i,
  output logic                     src_valid_o,
  output logic                     src_sop_o,
  output logic                     src_eop_o,
  output logic [c_EMPTY_W-1:0]     src_empty_o,
  output logic [g_DATA_WIDTH-1:0]  src_data_o
);

  // Empty width is log2ceil(g_DATA_WIDTH). That does not match
  // avst#(g_DATA_WIDTH)::master_init(), whose empty field uses symbol width 8.
  // The zero aggregate is the same bits as the VHDL c_AVST_INIT.
  `COLIBRI_AVST_MASTER_T(avst_t, g_DATA_WIDTH, c_EMPTY_W);
  localparam avst_t c_AVST_INIT = `COLIBRI_AVST_MASTER_INIT;

  (* preserve, dont_touch *) avst_t snk_avst_r;
  (* preserve, dont_touch *) avst_t src_avst_r;
  logic snk_feedback;
  logic snk_return;
  logic src_feedback;
  logic src_return;
  logic handshake;
  logic snk_reset;
  logic src_reset;

  synchro_reset snk_reset_inst (
    .clk_i   (snk_clk_i),
    .reset_i (reset_i),
    .reset_o (snk_reset)
  );

  synchro_reset src_reset_inst (
    .clk_i   (src_clk_i),
    .reset_i (reset_i),
    .reset_o (src_reset)
  );

  synchro #(
    .g_DATA_LENGTH (1)
  ) sync_feedback_snk_inst (
    .clk_i   (snk_clk_i),
    .reset_i (reset_i),
    .data_i  (src_feedback),
    .data_o  (snk_feedback)
  );

  synchro #(
    .g_DATA_LENGTH (1)
  ) sync_feedback_src_inst (
    .clk_i   (src_clk_i),
    .reset_i (reset_i),
    .data_i  (snk_return),
    .data_o  (src_return)
  );

  // The VHDL reset if is not an else. Later assignments override it.
  // Temps apply that last-assignment order without splitting one NBA.
  always_ff @(posedge snk_clk_i) begin : proc_snk_handle
    avst_t v_avst;
    logic  v_return;
    v_avst   = snk_avst_r;
    v_return = snk_return;
    if (snk_reset) begin
      v_return = 1'b0;
      v_avst   = c_AVST_INIT;
    end
    if (snk_ready_o == 1'b1) begin
      v_avst.sop   = snk_sop_i;
      v_avst.eop   = snk_eop_i;
      v_avst.empty = snk_empty_i;
      v_avst.data  = snk_data_i;
    end
    if (snk_valid_i == 1'b1)
      v_return = snk_feedback;
    snk_avst_r <= v_avst;
    snk_return <= v_return;
  end

  assign snk_ready_o = snk_feedback ^ snk_return;

  always_ff @(posedge src_clk_i) begin : proc_src_handle
    if (src_reset == 1'b1) begin
      src_feedback <= 1'b1;
      handshake    <= 1'b0;
      src_avst_r   <= c_AVST_INIT;
      src_valid_o  <= 1'b0;
    end else begin
      if ((src_return ^ handshake) && !src_valid_o) begin
        src_valid_o  <= 1'b1;
        src_avst_r   <= snk_avst_r;
        src_feedback <= ~src_feedback;
      end
      if (src_ready_i && src_valid_o) begin
        src_valid_o <= 1'b0;
        handshake   <= ~handshake;
      end
    end
  end

  assign src_sop_o   = src_avst_r.sop;
  assign src_eop_o   = src_avst_r.eop;
  assign src_empty_o = src_avst_r.empty;
  assign src_data_o  = src_avst_r.data;

endmodule
