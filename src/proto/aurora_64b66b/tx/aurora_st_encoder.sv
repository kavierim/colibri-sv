// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Aurora 64b/66b Encoder.
// Simplex multi-lane encoder. A 64-bit Avalon packet stream is encoded into
// Aurora lanes. A channel bonding word is sent every 64 cycles when more than
// one lane is used. After reset, idle words are sent for 64 cycles, then
// snk_ready_o is asserted.
// changelog:
// - 0.4 significant rewrite to clean up code (removed fifos)
// - 0.3b Update to VHDL Style Guideline
// - 0.3 Update to VHDL common library
// - 0.2 Adding Channel Bonding Feature
// - 0.1 first release

`timescale 1ns/1ps

module aurora_st_encoder #(
  parameter int unsigned g_N_LANES    = 1,
  // Kept for the VHDL generic list. Changelog 0.4 removed the encoder FIFO.
  // verilator lint_off UNUSEDPARAM
  parameter int unsigned g_FIFO_WORDS = 8,
  // verilator lint_on UNUSEDPARAM
  // Pad width below. Same lane count and different widths must not share one C++ type.
  parameter int unsigned g_LANE_WIDTH = 32
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic snk_valid_i,
  output logic snk_ready_o,
  input  logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] snk_data_i,
  input  logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] snk_empty_i,
  output logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] src_data_o [0:g_N_LANES-1],
  input  logic [g_N_LANES-1:0] src_ready_i,
  output logic [g_N_LANES-1:0] src_valid_o
);

  localparam int c_DATA_W    = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W     = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_EMPTY_W   = colibri_utils::log2ceil(c_DATA_W / 8);
  localparam int c_SHIFT16_W = c_DATA_W - 16;
  localparam int c_SHIFT8_W  = c_DATA_W - 8;
  localparam int c_SYNC_W    = colibri_utils::log2ceil(colibri_aurora_const::c_MAX_SYNC_CNT) + 1;

  typedef enum logic [2:0] {
    S_RESET,
    S_INIT,
    S_IDLE,
    S_DATA,
    S_EMPTY_SEP
  } fsm_t;

  // Lane arrays stay outside the record. Verilator 5.020 hits an internal
  // error on a variable index of an unpacked array that is a struct member.
  typedef struct {
    int unsigned ptr;
    fsm_t        state;
    fsm_t        reg_state;
    logic        stall;
    logic        empty;
    logic        ready;
    logic        valid;
    logic [g_LANE_WIDTH-1:0] lane_pad;
  } sig_t;

  logic                  sync_done;
  logic [c_SYNC_W-1:0]   sync_cnt;
  logic                  send_bond_frame;
  sig_t                  rreg;
  sig_t                  rcmb;
  logic [c_ENC_W-1:0]    r_lanes [0:g_N_LANES-1];
  logic [c_ENC_W-1:0]    c_lanes [0:g_N_LANES-1];
  logic [c_ENC_W-1:0]    r_odata [0:g_N_LANES-1];
  logic [c_ENC_W-1:0]    c_odata [0:g_N_LANES-1];

  function automatic sig_t fsm_init();
    sig_t v_init;
    v_init.ptr       = 0;
    v_init.state     = S_RESET;
    v_init.reg_state = S_RESET;
    v_init.stall     = 1'b0;
    v_init.empty     = 1'b1;
    v_init.ready     = 1'b0;
    v_init.valid     = 1'b0;
    v_init.lane_pad  = '0;
    return v_init;
  endfunction

  // bits#(48) and bits#(56) swap_endianness hit a Verilator 5.020 C++ bug
  // (static method, variable part-select). The byte order matches
  // colibri_utils::bits#(W)::swap_endianness.
  function automatic logic [c_SHIFT16_W-1:0] swap48(input logic [c_SHIFT16_W-1:0] vec);
    return {vec[7:0], vec[15:8], vec[23:16], vec[31:24], vec[39:32], vec[47:40]};
  endfunction

  function automatic logic [c_SHIFT8_W-1:0] swap56(input logic [c_SHIFT8_W-1:0] vec);
    return {vec[7:0], vec[15:8], vec[23:16], vec[31:24], vec[39:32], vec[47:40], vec[55:48]};
  endfunction

  function automatic logic [c_ENC_W-1:0] fill_lane(
    input logic [c_DATA_W-1:0]  data,
    input logic [c_EMPTY_W-1:0] empty
  );
    logic [c_ENC_W-1:0]    v_lane;
    logic [7:0]            v_valid_block;
    logic [c_SHIFT16_W-1:0] v_shift16;
    logic [c_SHIFT8_W-1:0]  v_shift8;
    if (empty != c_EMPTY_W'(1)) begin
      v_valid_block = 8'(8 - int'(empty));
      v_shift16     = data[c_DATA_W-1 -: c_SHIFT16_W];
      v_lane        = {colibri_aurora_const::c_CTRL_SH,
                       colibri_aurora_const::c_SEP_BLOCK,
                       v_valid_block,
                       swap48(v_shift16)};
    end else if (empty == c_EMPTY_W'(1)) begin
      v_shift8 = data[c_DATA_W-1 -: c_SHIFT8_W];
      v_lane   = {colibri_aurora_const::c_CTRL_SH,
                  colibri_aurora_const::c_SEP7_BLOCK,
                  swap56(v_shift8)};
    end else begin
      v_lane = {colibri_aurora_const::c_DATA_SH, data};
    end
    return v_lane;
  endfunction

  always_ff @(posedge clk_i) begin : proc_sync_cnt
    if (reset_i) begin
      sync_cnt  <= '0;
      sync_done <= 1'b0;
    end else if (!sync_done && (&src_ready_i)) begin
      sync_cnt <= sync_cnt + c_SYNC_W'(1);
      if (sync_cnt == c_SYNC_W'(colibri_aurora_const::c_MAX_SYNC_CNT))
        sync_done <= 1'b1;
    end
  end

  if (g_N_LANES > 1) begin : gen_channel_bond
    logic [7:0] ch_bond_cnt;

    always_ff @(posedge clk_i) begin : proc_channel_bond_trigger
      if (reset_i) begin
        ch_bond_cnt     <= '0;
        send_bond_frame <= 1'b0;
      end else if (&src_ready_i) begin
        if (ch_bond_cnt == 8'(colibri_aurora_const::c_CH_BOND_CYCLES)) begin
          send_bond_frame <= 1'b1;
          ch_bond_cnt     <= '0;
        end else begin
          send_bond_frame <= 1'b0;
          ch_bond_cnt     <= ch_bond_cnt + 8'd1;
        end
      end
    end
  end else begin : gen_no_channel_bond
    // VHDL left the architecture signal at its '0' initializer when N is 1.
    assign send_bond_frame = 1'b0;
  end

  always_ff @(posedge clk_i) begin : proc_fsm_reg
    rreg    <= rcmb;
    r_lanes <= c_lanes;
    r_odata <= c_odata;
  end

  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int   = rreg;
    c_lanes = r_lanes;
    c_odata = r_odata;

    if (rreg.empty)
      v_int.valid = 1'b0;

    if ((&src_ready_i) && !rreg.empty && !send_bond_frame) begin
      v_int.valid = 1'b0;
      v_int.empty = 1'b1;
    end

    v_int.ready = v_int.empty;

    if (v_int.empty)
      c_lanes[rreg.ptr] = colibri_aurora_const::c_IDLE_WORD;

    case (rreg.state)
      S_RESET: begin
        v_int.ready = 1'b0;
        v_int.state = S_INIT;
      end
      S_INIT: begin
        v_int.ready = 1'b0;
        if (sync_done)
          v_int.state = S_IDLE;
      end
      S_IDLE: begin
        if (snk_valid_i && v_int.empty && snk_sop_i) begin
          if (snk_eop_i) begin
            if (snk_empty_i != '0) begin
              c_lanes[rreg.ptr] = fill_lane(snk_data_i, snk_empty_i);
              v_int.state           = S_IDLE;
            end else begin
              c_lanes[rreg.ptr] = {colibri_aurora_const::c_DATA_SH,
                                        colibri_utils::bits#(c_DATA_W)::swap_endianness(snk_data_i)};
              v_int.state           = S_EMPTY_SEP;
            end
          end else begin
            c_lanes[rreg.ptr] = {colibri_aurora_const::c_DATA_SH,
                                      colibri_utils::bits#(c_DATA_W)::swap_endianness(snk_data_i)};
            v_int.state           = S_DATA;
          end
        end
      end
      S_DATA: begin
        if (snk_valid_i && v_int.empty) begin
          if (snk_eop_i) begin
            if (snk_empty_i != '0) begin
              c_lanes[rreg.ptr] = fill_lane(snk_data_i, snk_empty_i);
              v_int.state           = S_IDLE;
            end else begin
              c_lanes[rreg.ptr] = {colibri_aurora_const::c_DATA_SH,
                                        colibri_utils::bits#(c_DATA_W)::swap_endianness(snk_data_i)};
              v_int.state           = S_EMPTY_SEP;
            end
          end else begin
            c_lanes[rreg.ptr] = {colibri_aurora_const::c_DATA_SH,
                                      colibri_utils::bits#(c_DATA_W)::swap_endianness(snk_data_i)};
          end
        end
      end
      S_EMPTY_SEP: begin
        v_int.ready = 1'b0;
        if (v_int.empty) begin
          c_lanes[rreg.ptr] = colibri_aurora_const::c_EMPTY_SEP_WORD;
          v_int.state           = S_IDLE;
        end
      end
      default: begin
      end
    endcase

    if (v_int.empty) begin
      if (v_int.ptr == g_N_LANES - 1) begin
        v_int.ptr   = 0;
        v_int.empty = 1'b0;
        v_int.valid = 1'b1;
      end else begin
        v_int.ptr = rreg.ptr + 1;
      end
    end

    if (&src_ready_i) begin
      if (send_bond_frame) begin
        for (int lane = 0; lane < g_N_LANES; lane++)
          c_odata[lane] = colibri_aurora_const::c_CB_WORD;
      end else if (rreg.valid) begin
        c_odata = r_lanes;
      end else begin
        for (int lane = 0; lane < g_N_LANES; lane++)
          c_odata[lane] = colibri_aurora_const::c_IDLE_WORD;
      end
    end

    if (reset_i) begin
      v_int = fsm_init();
      for (int lane = 0; lane < g_N_LANES; lane++) begin
        c_lanes[lane] = '0;
        c_odata[lane] = colibri_aurora_const::c_IDLE_WORD;
      end
    end

    rcmb = v_int;
  end

  assign snk_ready_o = rcmb.ready;
  for (genvar lane = 0; lane < g_N_LANES; lane++) begin : gen_src_data
    assign src_data_o[lane] = r_odata[lane];
  end
  assign src_valid_o = {g_N_LANES{~reset_i}};

endmodule
