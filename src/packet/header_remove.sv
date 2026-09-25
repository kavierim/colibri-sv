// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Removes g_HEADER_BYTES from the front of an Avalon-ST packet and presents
// that header on src_header_o with the output start of packet.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module header_remove #(
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
  // The VHDL architecture does not read snk_sop_i. The port stays on the entity.
  // verilator lint_off UNUSEDSIGNAL
  input  logic                    snk_sop_i,
  // verilator lint_on UNUSEDSIGNAL
  input  logic                    snk_eop_i,
  input  logic                    snk_valid_i,
  output logic                    snk_ready_o,
  input  logic [c_DATA_W-1:0]     snk_data_i,
  input  logic [c_EMPTY_W-1:0]    snk_empty_i,
  output logic                    src_sop_o,
  output logic                    src_eop_o,
  output logic                    src_valid_o,
  input  logic                    src_ready_i,
  output logic [c_DATA_W-1:0]     src_data_o,
  output logic [c_EMPTY_W-1:0]    src_empty_o,
  output logic [c_HDR_BITS-1:0]   src_header_o
);

  typedef colibri_types::avst#(c_DATA_W, 8) avst_cls;
  `COLIBRI_AVST_MASTER_T(avst_t, c_DATA_W, c_EMPTY_W);

  typedef enum logic [1:0] {
    S_IDLE,
    S_HEADER,
    S_DATA
  } fsm_t;

  typedef struct {
    fsm_t  state;
    avst_t avst;
    logic  ready;
    int    head_cnt;
  } fsm_signals_t;

  function automatic avst_t avst_init();
    return avst_t'(avst_cls::master_init());
  endfunction

  function automatic fsm_signals_t fsm_init();
    fsm_signals_t v;
    v.state    = S_IDLE;
    v.avst     = avst_init();
    v.ready    = 1'b0;
    v.head_cnt = 0;
    return v;
  endfunction

  avst_t iavst;
  logic  shift_avst_ready;
  // VHDL leaves be_remove_lead.src_head_o open.
  // verilator lint_off UNUSEDSIGNAL
  logic [c_DATA_W-1:0] src_head_unused;
  // verilator lint_on UNUSEDSIGNAL
  fsm_signals_t rreg;
  fsm_signals_t rcmb;
  // Kept outside the FSM struct. A wide array element written through the
  // struct is dropped by Verilator 5.020, so the header stayed zero.
  logic [c_DATA_W-1:0] head_q [0:c_HEADER_WORDS-1];
  logic head_capture;
  assign head_capture = (rreg.state == S_HEADER) && iavst.valid && rreg.ready && !reset_i;

  initial rreg = fsm_init();

  // sop is never driven in the VHDL; the record starts at avst_master_init.
  assign iavst.eop   = snk_eop_i;
  assign iavst.valid = snk_valid_i;
  assign iavst.data  = snk_data_i;
  assign iavst.empty = snk_empty_i;
  assign iavst.sop   = 1'b0;

  always_comb begin : proc_fsm_cmb
    fsm_signals_t v_int;
    v_int = rreg;
    v_int.ready = shift_avst_ready;

    if (rreg.avst.valid & shift_avst_ready)
      v_int.avst = avst_init();

    v_int.ready = (~rreg.avst.valid) & shift_avst_ready;

    case (rreg.state)
      S_IDLE: begin
        v_int       = fsm_init();
        v_int.state = S_HEADER;
      end
      S_HEADER: begin
        if (iavst.valid & rreg.ready) begin
          if (rreg.head_cnt != c_HEADER_WORDS - 1) begin
            v_int.head_cnt = rreg.head_cnt + 1;
          end else begin
            v_int.avst     = iavst;
            v_int.avst.sop = 1'b1;
            v_int.state    = S_DATA;
          end
          if (iavst.eop == 1'b1) begin
            // Keep sop when this beat both finishes the header and ends the
            // packet. A full copy of iavst clears sop, and the lead remover
            // then never starts.
            logic sop_keep;
            sop_keep       = v_int.avst.sop;
            v_int.avst     = iavst;
            v_int.avst.sop = sop_keep;
            v_int.ready    = 1'b0;
            v_int.state    = S_IDLE;
          end
        end
      end
      S_DATA: begin
        if (iavst.valid & rreg.ready) begin
          v_int.avst = iavst;
          if (iavst.eop == 1'b1) begin
            v_int.ready = 1'b0;
            v_int.state = S_IDLE;
          end
        end
      end
      default: begin
      end
    endcase

    if (reset_i == 1'b1)
      v_int = fsm_init();

    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_fsm_reg
    rreg <= rcmb;
  end

  assign snk_ready_o = rreg.ready;

  for (genvar gi = 0; gi < c_HEADER_WORDS; gi++) begin : gen_head_cap
    always_ff @(posedge clk_i) begin
      if (reset_i)
        head_q[gi] <= '0;
      else if (head_capture && rreg.head_cnt == gi)
        head_q[gi] <= snk_data_i;
    end
  end

  be_remove_lead #(
    .g_DATA_WIDTH   (g_DATA_WIDTH),
    .g_REGISTER_OUT (1'b1)
  ) be_remove_lead_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .shl_i       (c_SHL_W'(c_HEADER_VALID)),
    .snk_ready_o (shift_avst_ready),
    .snk_valid_i (rreg.avst.valid),
    .snk_sop_i   (rreg.avst.sop),
    .snk_eop_i   (rreg.avst.eop),
    .snk_empty_i (rreg.avst.empty),
    .snk_data_i  (rreg.avst.data),
    .src_ready_i (src_ready_i),
    .src_valid_o (src_valid_o),
    .src_sop_o   (src_sop_o),
    .src_eop_o   (src_eop_o),
    .src_empty_o (src_empty_o),
    .src_data_o  (src_data_o),
    .src_head_o  (src_head_unused)
  );

  // One header word: the wide slice in the multi-word loop is out of range
  // when g_DATA_WIDTH exceeds the header, and Verilator elaborates it anyway.
  if (c_HEADER_WORDS <= 1) begin : gen_header_one
    always_comb begin : proc_convert_header
      src_header_o = '0;
      if (src_valid_o && src_sop_o)
        src_header_o = head_q[0][c_DATA_W-1 -: c_HDR_BITS];
    end
  end else begin : gen_header_many
    always_comb begin : proc_convert_header
      src_header_o = '0;
      if (src_valid_o && src_sop_o) begin
        for (int i = 0; i < c_HEADER_WORDS - 1; i++)
          src_header_o[(c_HDR_BITS - 1) - (i * c_DATA_W) -: c_DATA_W] = head_q[i];
        src_header_o[c_LAST_BITS-1:0] =
          head_q[c_HEADER_WORDS-1][c_DATA_W-1 -: c_LAST_BITS];
      end
    end
  end

endmodule
// verilator lint_on MULTITOP
