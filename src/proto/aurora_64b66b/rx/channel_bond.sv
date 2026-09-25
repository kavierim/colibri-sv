// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Aurora Multi Lane Bonding.
// Each lane is fed to a dedicated FIFO. The FIFOs are read until a channel
// bond word is seen. Once every FIFO shows a bond word, skew is compensated
// and src_bond_o is asserted.
// changelog:
// - 0.1 first release
// - 0.1b: update to lhcb vhdl style guideline

`timescale 1ns/1ps

module channel_bond #(
  parameter int unsigned g_N_LANES      = 1,
  parameter int unsigned g_BUF_SIZE     = 8,
  parameter bit          g_REGISTER_OUT = 1'b1
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] snk_data_i [0:g_N_LANES-1],
  input  logic [g_N_LANES-1:0] snk_valid_i,
  output logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] src_data_o [0:g_N_LANES-1],
  output logic [g_N_LANES-1:0] src_valid_o,
  output logic src_bond_o
);

  localparam int c_ENC_W  = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_BOND_W = 18;
  localparam logic [c_BOND_W-1:0] c_BOND_TAG = {
    colibri_aurora_const::c_CTRL_SH,
    colibri_aurora_const::c_IDLE_CB_BLOCK,
    colibri_aurora_const::c_CB_CODE
  };

  typedef enum logic [2:0] {
    S_RESET_I,
    S_IDLE,
    S_TEST_BOND,
    S_ALIGN,
    S_CH_BOND
  } fsm_t;

  logic [g_N_LANES-1:0] read_en;
  logic [g_N_LANES-1:0] fifo_empty;
  logic [g_N_LANES-1:0] fifo_full;
  logic [g_N_LANES-1:0] is_bond_frame;
  logic [c_ENC_W-1:0]   o_data [0:g_N_LANES-1];
  logic [g_N_LANES-1:0] o_valid;
  logic [g_N_LANES-1:0] reset_i_fifo;
  logic [g_N_LANES-1:0] bond_done;
  logic                 bond_all;

  assign bond_all = &bond_done;

  `COLIBRI_WHEN_REGISTERED(src_data, clk_i, g_REGISTER_OUT, src_data_o, o_data)
  `COLIBRI_WHEN_REGISTERED(src_valid, clk_i, g_REGISTER_OUT, src_valid_o, o_valid)
  `COLIBRI_WHEN_REGISTERED(src_bond, clk_i, g_REGISTER_OUT, src_bond_o, bond_all)

  for (genvar i = 0; i < g_N_LANES; i++) begin : gen_fifos
    // verilator lint_off PINMISSING
    fifo #(
      .g_NUM_WORDS(int'(g_BUF_SIZE)),
      .g_INPUT_WIDTH(c_ENC_W),
      .g_OUTPUT_WIDTH(c_ENC_W)
    ) ch_bond_fifo (
      .reset_i(&reset_i_fifo),
      .clk_i(clk_i),
      .data_i(snk_data_i[i]),
      .wrreq_i(snk_valid_i[i]),
      .rdreq_i(read_en[i]),
      .q_o(o_data[i]),
      .empty_o(fifo_empty[i]),
      .full_o(fifo_full[i])
    );
    // verilator lint_on PINMISSING
  end

  for (genvar i = 0; i < g_N_LANES; i++) begin : gen_lane_fsm
    fsm_t state = S_IDLE;
    fsm_t next_state;

    assign is_bond_frame[i] = (o_data[i][c_ENC_W-1 -: c_BOND_W] == c_BOND_TAG);

    always_ff @(posedge clk_i) begin : proc_fsm_clk
      if (reset_i) begin
        state        <= S_RESET_I;
        o_valid[i]   <= 1'b0;
        bond_done[i] <= 1'b0;
      end else begin
        state <= next_state;
        if (state == S_CH_BOND) begin
          bond_done[i] <= 1'b1;
          o_valid[i]   <= read_en[i];
        end else begin
          bond_done[i] <= 1'b0;
          o_valid[i]   <= 1'b0;
        end
      end
    end

    always_comb begin : proc_fsm_cmb
      reset_i_fifo[i] = 1'b0;
      next_state      = state;
      read_en[i]      = 1'b0;

      case (state)
        S_RESET_I: begin
          next_state      = S_IDLE;
          reset_i_fifo[i] = 1'b1;
        end
        S_IDLE: begin
          if ((|fifo_empty) == 1'b0) begin
            next_state = S_TEST_BOND;
            read_en[i] = 1'b1;
          end
        end
        S_TEST_BOND: begin
          read_en[i] = 1'b1;
          if (is_bond_frame[i]) begin
            read_en[i] = 1'b0;
            if (&is_bond_frame)
              next_state = S_CH_BOND;
            else
              next_state = S_ALIGN;
          end
        end
        S_ALIGN: begin
          if (&is_bond_frame)
            next_state = S_CH_BOND;
        end
        S_CH_BOND: begin
          if (~(|fifo_empty))
            read_en[i] = 1'b1;
          if ((&o_valid) && (|is_bond_frame) && !(&is_bond_frame)) begin
            reset_i_fifo[i] = 1'b1;
            next_state      = S_IDLE;
          end
        end
        default: begin
        end
      endcase

      if (|fifo_full) begin
        reset_i_fifo[i] = 1'b1;
        next_state      = S_IDLE;
      end
    end
  end

endmodule
