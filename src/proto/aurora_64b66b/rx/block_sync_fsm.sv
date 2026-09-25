// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Block Sync FSM.
// Determines and checks the link lock status.
// See Aurora FSM flowchart and IEEE 802.3ae fig 49-14 (rev.2022).
// changelog:
// - 0.1 first release
// - 0.1b: update to lhcb vhdl style guideline

`timescale 1ns/1ps

module block_sync_fsm #(
  parameter int unsigned g_SH_CNT_MAX         = 64,
  parameter int unsigned g_SH_INVALID_CNT_MAX = 16,
  parameter int unsigned g_SLIP_CNT_MAX       = 32
) (
  input  logic       clk_i,
  input  logic       reset_i,
  input  logic [1:0] snk_meta_i,
  input  logic       snk_valid_i,
  output logic       snk_slip_o,
  output logic       src_sync_o
);

  typedef enum logic [2:0] {
    S_LOCK_INIT,
    S_RESET_CNT,
    S_TEST_SH,
    S_VALID_SH,
    S_INVALID_SH,
    S_64_GOOD,
    S_SLIP
  } fsm_t;

  // VHDL `unsigned(log2ceil(max) downto 0)` is one bit wider than log2ceil.
  localparam int c_SH_W     = colibri_utils::log2ceil(int'(g_SH_CNT_MAX)) + 1;
  localparam int c_SH_INV_W = colibri_utils::log2ceil(int'(g_SH_INVALID_CNT_MAX)) + 1;
  localparam int c_SLIP_W   = colibri_utils::log2ceil(int'(g_SLIP_CNT_MAX)) + 1;

  fsm_t state = S_LOCK_INIT;
  fsm_t next_state;

  logic                  sh_found;
  logic                  block_lock;
  logic                  slip_done;
  logic [c_SH_W-1:0]     sh_cnt;
  logic [c_SH_INV_W-1:0] sh_invalid_cnt;
  logic [c_SLIP_W-1:0]   slip_cnt;

  assign sh_found = (snk_meta_i == colibri_aurora_const::c_CTRL_SH) ||
                    (snk_meta_i == colibri_aurora_const::c_DATA_SH);

  always_ff @(posedge clk_i) begin : proc_fsm_clk
    if (reset_i) begin
      state          <= S_LOCK_INIT;
      sh_cnt         <= '0;
      sh_invalid_cnt <= '0;
      slip_cnt       <= '0;
      slip_done      <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_RESET_CNT: begin
          sh_cnt         <= '0;
          sh_invalid_cnt <= '0;
          slip_cnt       <= '0;
          slip_done      <= 1'b0;
        end
        S_VALID_SH: begin
          sh_cnt   <= sh_cnt + c_SH_W'(1);
          slip_cnt <= '0;
        end
        S_INVALID_SH: begin
          sh_cnt         <= sh_cnt + c_SH_W'(1);
          sh_invalid_cnt <= sh_invalid_cnt + c_SH_INV_W'(1);
          slip_cnt       <= '0;
        end
        S_SLIP: begin
          slip_cnt  <= slip_cnt + c_SLIP_W'(1);
          slip_done <= (slip_cnt == c_SLIP_W'(g_SLIP_CNT_MAX));
        end
        default: begin
        end
      endcase

      src_sync_o <= block_lock;
    end
  end

  always_comb begin : proc_fsm_comb
    next_state = state;
    block_lock = src_sync_o;
    snk_slip_o = 1'b0;

    case (state)
      S_LOCK_INIT: begin
        block_lock = 1'b0;
        next_state = S_RESET_CNT;
      end
      S_RESET_CNT: begin
        next_state = S_TEST_SH;
      end
      S_TEST_SH: begin
        if (snk_valid_i) begin
          if (sh_found)
            next_state = S_VALID_SH;
          else
            next_state = S_INVALID_SH;
        end
      end
      S_VALID_SH: begin
        if (sh_cnt == c_SH_W'(g_SH_CNT_MAX)) begin
          if (sh_invalid_cnt == '0)
            next_state = S_64_GOOD;
          else if (sh_invalid_cnt > '0)
            next_state = S_RESET_CNT;
        end else begin
          next_state = S_TEST_SH;
        end
      end
      S_INVALID_SH: begin
        if ((block_lock == 1'b0) || (sh_invalid_cnt == c_SH_INV_W'(g_SH_INVALID_CNT_MAX))) begin
          next_state = S_SLIP;
          snk_slip_o = 1'b1;
        end else begin
          if (sh_cnt == c_SH_W'(g_SH_CNT_MAX))
            next_state = S_RESET_CNT;
          else
            next_state = S_TEST_SH;
        end
      end
      S_64_GOOD: begin
        block_lock = 1'b1;
        next_state = S_RESET_CNT;
      end
      S_SLIP: begin
        if (slip_done)
          next_state = S_RESET_CNT;
        block_lock = 1'b0;
      end
      default: begin
      end
    endcase
  end

endmodule
