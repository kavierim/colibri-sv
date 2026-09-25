// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Continuous Stream Upsizing Gearbox.
// Generic upscaling gearbox for continuous streams on a single clock domain.
// It includes a slip signal to shift the output (1 bit resolution).
// Inspired by the work of Timon Heim for Yarr.
// changelog:
// - 0.1: initial release

`timescale 1ns/1ps

module gearbox_up #(
  parameter int g_INPUT_WIDTH,
  parameter int g_OUTPUT_WIDTH
) (
  input  logic                         clk_i,
  input  logic                         reset_i,
  input  logic                         slip_i,
  input  logic [g_INPUT_WIDTH-1:0]     snk_data_i,
  input  logic                         snk_valid_i,
  output logic [g_OUTPUT_WIDTH-1:0]    src_data_o,
  output logic                         src_valid_o
);

  localparam int c_MIN       = colibri_utils::minimum(g_INPUT_WIDTH, g_OUTPUT_WIDTH);
  localparam int c_MAX       = colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH);
  localparam int c_LCM       = colibri_utils::least_common_mult(g_INPUT_WIDTH, g_OUTPUT_WIDTH);
  localparam int c_REMAINDER = c_MAX % c_MIN;
  localparam int c_MAX_COUNT = c_LCM / c_MIN;
  localparam int c_MAX_SHIFT = c_MAX / c_MIN;
  localparam int c_FLOOR     = (c_MAX / c_MIN) * c_MIN;
  localparam int c_BUF_SIZE  = c_MAX + c_FLOOR;

  // VHDL `unsigned(log2ceil(c_MAX_COUNT - 1) downto 0)`.
  localparam int c_POS_W      = colibri_utils::log2ceil(c_MAX_COUNT - 1);
  localparam int c_GBX_CNT_W  = c_POS_W + 1;
  // VHDL null slice when log2ceil returns 0. Keep the select in range.
  localparam int c_POS_SLICE_W = (c_POS_W > 0) ? c_POS_W : 1;

  logic [c_GBX_CNT_W-1:0]  gearbox_cnt;
  int                      shift_cnt;
  // VHDL name `buf` is a Verilog gate primitive.
  logic [c_BUF_SIZE-1:0]   gear_buf;
  logic                    buf_watermark;
  int                      slip_cnt;
  logic                    slip_seen;

  // Reset is asynchronous: the VHDL process checks reset_i before rising_edge.
  always_ff @(posedge clk_i or posedge reset_i) begin : proc_shift
    int v_pos;
    int v_off;
    logic                      next_src_valid;
    logic [c_BUF_SIZE-1:0]     next_buf;
    logic [c_GBX_CNT_W-1:0]    next_gbx_cnt;
    int                        next_shift;
    int                        next_slip;
    logic                      next_watermark;
    logic                      next_slip_seen;
    logic [g_OUTPUT_WIDTH-1:0] next_src_data;

    if (reset_i) begin
      gear_buf      <= '0;
      gearbox_cnt   <= '0;
      src_valid_o   <= 1'b0;
      src_data_o    <= '0;
      shift_cnt     <= 0;
      slip_cnt      <= 0;
      buf_watermark <= 1'b0;
      slip_seen     <= 1'b0;
    end else begin
      // Later VHDL signal assignments override earlier ones in this process.
      next_src_valid = 1'b0;
      next_buf       = gear_buf;
      next_gbx_cnt   = gearbox_cnt;
      next_shift     = shift_cnt;
      next_slip      = slip_cnt;
      next_watermark = buf_watermark;
      next_slip_seen = slip_seen;
      next_src_data  = src_data_o;

      if (snk_valid_i) begin
        next_shift = shift_cnt + 1;
        next_buf   = {gear_buf[c_BUF_SIZE-g_INPUT_WIDTH-1:0], snk_data_i};
        v_pos      = (c_POS_W > 0) ? int'(gearbox_cnt[c_POS_SLICE_W-1:0]) : 0;
        v_off      = c_BUF_SIZE - c_REMAINDER - (v_pos * c_REMAINDER - slip_cnt);
        if (slip_i)
          next_slip_seen = 1'b1;
        if ((shift_cnt == c_MAX_SHIFT - 1) && buf_watermark) begin
          next_shift     = 0;
          next_src_valid = 1'b1;
          if (gearbox_cnt == c_GBX_CNT_W'(c_MAX_COUNT - 1)) begin
            next_gbx_cnt   = '0;
            next_src_valid = 1'b0;
          end else begin
            next_gbx_cnt  = gearbox_cnt + c_GBX_CNT_W'(1);
            // Slice the buffer value from before this cycle's shift.
            next_src_data = gear_buf[v_off-1 -: g_OUTPUT_WIDTH];
          end
          if (slip_seen) begin
            next_slip_seen = 1'b0;
            if (slip_cnt == c_REMAINDER - 1) begin
              next_slip    = 0;
              next_gbx_cnt = gearbox_cnt;
            end else begin
              next_slip = slip_cnt + 1;
            end
          end
        end else if ((shift_cnt == (c_BUF_SIZE / g_INPUT_WIDTH) - c_MAX_SHIFT) && !buf_watermark) begin
          next_watermark = 1'b1;
          next_shift     = 0;
        end
      end

      src_valid_o   <= next_src_valid;
      gear_buf      <= next_buf;
      gearbox_cnt   <= next_gbx_cnt;
      shift_cnt     <= next_shift;
      slip_cnt      <= next_slip;
      buf_watermark <= next_watermark;
      slip_seen     <= next_slip_seen;
      src_data_o    <= next_src_data;
    end
  end

endmodule
