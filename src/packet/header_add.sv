// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Inserts snk_header_i, sampled at the input start of packet, in front of an
// Avalon-ST packet.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module header_add #(
  parameter int unsigned g_HEADER_BYTES = 14,
  parameter int unsigned g_DATA_WIDTH   = 32,
  localparam int c_DATA_W       = int'(g_DATA_WIDTH),
  localparam int c_EMPTY_W      = colibri_types::avst_empty_width(c_DATA_W, 8),
  localparam int c_HDR_BITS     = int'(g_HEADER_BYTES) * 8,
  localparam int c_WORD_BYTES   = c_DATA_W / 8,
  localparam int c_HEADER_WORDS = colibri_utils::div_ceil(int'(g_HEADER_BYTES), c_WORD_BYTES),
  localparam int c_HEADER_EMPTY = c_HEADER_WORDS * c_WORD_BYTES - int'(g_HEADER_BYTES),
  localparam int c_HEADER_VALID = int'(g_HEADER_BYTES) - (c_HEADER_WORDS - 1) * c_WORD_BYTES,
  localparam int c_LAST_BITS    = c_HEADER_VALID * 8,
  localparam int c_SHL_W        = colibri_utils::log2ceil(c_WORD_BYTES) + 1
) (
  input  logic                    clk_i,
  input  logic                    reset_i,
  input  logic                    snk_sop_i,
  input  logic                    snk_eop_i,
  input  logic                    snk_valid_i,
  output logic                    snk_ready_o,
  input  logic [c_DATA_W-1:0]     snk_data_i,
  input  logic [c_EMPTY_W-1:0]    snk_empty_i,
  input  logic [c_HDR_BITS-1:0]   snk_header_i,
  output logic                    src_sop_o,
  output logic                    src_eop_o,
  output logic                    src_valid_o,
  input  logic                    src_ready_i,
  output logic [c_DATA_W-1:0]     src_data_o,
  output logic [c_EMPTY_W-1:0]    src_empty_o
);

  typedef colibri_types::avst#(c_DATA_W, 8) avst_cls;
  `COLIBRI_AVST_MASTER_T(avst_t, c_DATA_W, c_EMPTY_W);

  typedef enum logic [1:0] {
    S_IDLE,
    S_ADD_HEADER,
    S_ADD_DATA,
    S_EOP
  } fsm_t;

  typedef struct packed {
    fsm_t                  state;
    avst_t                 avst;
    // A 32-bit int in this packed record is not read as the field.
    logic [7:0]            head_cnt;
    logic [c_HDR_BITS-1:0] header;
  } fsm_signals_t;

  function automatic avst_t avst_init();
    return avst_t'(avst_cls::master_init());
  endfunction

  function automatic fsm_signals_t fsm_init();
    fsm_signals_t v;
    v.state    = S_IDLE;
    v.avst     = avst_init();
    v.head_cnt = 0;
    v.header   = '0;
    return v;
  endfunction

  logic [c_DATA_W-1:0] header_arr [0:c_HEADER_WORDS-1];
  logic [c_DATA_W-1:0] head_piece [0:c_HEADER_WORDS-1];
  logic [c_DATA_W-1:0] head_word;
  avst_t               shift_avst;
  logic                shift_avst_ready;
  avst_t               int_oavst;
  logic                int_oavst_ready;
  fsm_signals_t        fsm_reg;
  fsm_signals_t        fsm_cmb;

  initial fsm_reg = fsm_init();

  be_add_lead #(
    .g_DATA_WIDTH (g_DATA_WIDTH)
  ) be_add_lead_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .shl_i       (c_SHL_W'(c_HEADER_VALID)),
    .snk_ready_o (snk_ready_o),
    .snk_valid_i (snk_valid_i),
    .snk_sop_i   (snk_sop_i),
    .snk_eop_i   (snk_eop_i),
    .snk_empty_i (snk_empty_i),
    .snk_data_i  (snk_data_i),
    .snk_lead_i  ({c_DATA_W{1'b0}}),
    .src_ready_i (shift_avst_ready),
    .src_valid_o (shift_avst.valid),
    .src_sop_o   (shift_avst.sop),
    .src_eop_o   (shift_avst.eop),
    .src_empty_o (shift_avst.empty),
    .src_data_o  (shift_avst.data)
  );

  // The wide slice is only legal when the header spans more than one word.
  // A dead branch still elaborates under Verilator and SELRANGE-fails.
  if (c_HEADER_WORDS > 1) begin : gen_hdr_many
    always_comb begin : proc_convert_header
      for (int i = 0; i < c_HEADER_WORDS; i++) begin
        if (i < c_HEADER_WORDS - 1)
          header_arr[i] = fsm_reg.header[(c_HDR_BITS - 1) - (i * c_DATA_W) -: c_DATA_W];
        else begin
          header_arr[i] = '0;
          header_arr[i][c_DATA_W-1:c_HEADER_EMPTY * 8] = fsm_reg.header[c_LAST_BITS-1:0];
        end
      end
    end
  end else begin : gen_hdr_one
    always_comb begin : proc_convert_header
      header_arr[0] = '0;
      header_arr[0][c_DATA_W-1 -: c_LAST_BITS] = fsm_reg.header[c_LAST_BITS-1:0];
    end
  end

  // Constant index. A variable read of header_arr returns zero.
  // A reduction array of these pieces is treated as a combinational loop.
  for (genvar gi = 0; gi < c_HEADER_WORDS; gi++) begin : gen_head_sel
    assign head_piece[gi] = (fsm_reg.head_cnt == 8'(gi)) ? header_arr[gi] : '0;
  end
  if (c_HEADER_WORDS == 1) begin : gen_hw1
    assign head_word = head_piece[0];
  end else if (c_HEADER_WORDS == 2) begin : gen_hw2
    assign head_word = head_piece[0] | head_piece[1];
  end else if (c_HEADER_WORDS == 3) begin : gen_hw3
    assign head_word = head_piece[0] | head_piece[1] | head_piece[2];
  end else if (c_HEADER_WORDS == 8) begin : gen_hw8
    assign head_word = head_piece[0] | head_piece[1] | head_piece[2] | head_piece[3]
                     | head_piece[4] | head_piece[5] | head_piece[6] | head_piece[7];
  end else if (c_HEADER_WORDS == 14) begin : gen_hw14
    assign head_word = head_piece[0] | head_piece[1] | head_piece[2] | head_piece[3]
                     | head_piece[4] | head_piece[5] | head_piece[6] | head_piece[7]
                     | head_piece[8] | head_piece[9] | head_piece[10] | head_piece[11]
                     | head_piece[12] | head_piece[13];
  end else if (c_HEADER_WORDS == 20) begin : gen_hw20
    assign head_word = head_piece[0] | head_piece[1] | head_piece[2] | head_piece[3]
                     | head_piece[4] | head_piece[5] | head_piece[6] | head_piece[7]
                     | head_piece[8] | head_piece[9] | head_piece[10] | head_piece[11]
                     | head_piece[12] | head_piece[13] | head_piece[14] | head_piece[15]
                     | head_piece[16] | head_piece[17] | head_piece[18] | head_piece[19];
  end else begin : gen_hw_bad
    assign head_word = '0;
  end

  always_comb begin : proc_fsm_cmb
    fsm_signals_t v_int;
    v_int = fsm_reg;
    shift_avst_ready = 1'b0;

    if (snk_sop_i == 1'b1 && snk_valid_i == 1'b1 && snk_ready_o == 1'b1)
      v_int.header = snk_header_i;

    case (fsm_reg.state)
      S_IDLE: begin
        v_int.avst       = avst_init();
        shift_avst_ready = 1'b0;
        if (shift_avst.valid == 1'b1 && int_oavst_ready == 1'b1) begin
          v_int.avst.sop   = 1'b1;
          v_int.avst.valid = 1'b1;
          if (fsm_reg.head_cnt != 8'(c_HEADER_WORDS - 1)) begin
            v_int.avst.data = header_arr[0];
            v_int.head_cnt  = fsm_reg.head_cnt + 8'd1;
            v_int.state     = S_ADD_HEADER;
          end else begin
            shift_avst_ready = 1'b1;
            v_int.avst       = shift_avst;
            v_int.avst.data  = header_arr[0] | shift_avst.data;
            v_int.head_cnt   = 0;
            v_int.state      = S_ADD_DATA;
            if (shift_avst.eop == 1'b1)
              v_int.state = S_EOP;
          end
        end
      end
      S_ADD_HEADER: begin
        if (int_oavst_ready == 1'b1) begin
          v_int.avst       = shift_avst;
          v_int.avst.sop   = 1'b0;
          v_int.avst.valid = 1'b1;
          if (fsm_reg.head_cnt != 8'(c_HEADER_WORDS - 1)) begin
            v_int.avst.eop  = 1'b0;
            v_int.avst.data = head_word;
            v_int.head_cnt  = fsm_reg.head_cnt + 8'd1;
          end else begin
            shift_avst_ready = 1'b1;
            v_int.avst.data  = head_word | shift_avst.data;
            v_int.head_cnt   = 0;
            v_int.state      = S_ADD_DATA;
            if (shift_avst.eop == 1'b1)
              v_int.state = S_EOP;
          end
        end
      end
      S_ADD_DATA: begin
        if (int_oavst_ready == 1'b1) begin
          shift_avst_ready = 1'b1;
          v_int.avst       = shift_avst;
          v_int.avst.sop   = 1'b0;
          if (shift_avst.eop == 1'b1)
            v_int.state = S_EOP;
        end
      end
      S_EOP: begin
        if (int_oavst_ready == 1'b1) begin
          v_int.avst  = avst_init();
          v_int.state = S_IDLE;
        end
      end
      default: begin
      end
    endcase

    if (reset_i == 1'b1)
      v_int = fsm_init();

    fsm_cmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_fsm_reg
    fsm_reg <= fsm_cmb;
  end

  assign int_oavst       = fsm_reg.avst;
  assign int_oavst_ready = src_ready_i;
  assign src_valid_o     = int_oavst.valid;
  assign src_sop_o       = int_oavst.sop;
  assign src_eop_o       = int_oavst.eop;
  assign src_empty_o     = int_oavst.empty;
  assign src_data_o      = int_oavst.data;

endmodule
// verilator lint_on MULTITOP
