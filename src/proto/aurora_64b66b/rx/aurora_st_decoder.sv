// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Aurora 64b/66b Decoder.
// Simplex multi-lane decoder. snk_link_up_i marks the end of link training
// and channel bonding. The first packet is dropped. src_error_o is set when
// the link drops mid-packet, or when a bond word arrives on a single lane.
// Changelog:
// - 0.5 Channel Bond lane mismatch error handling
// - 0.4 code cleanup rewriting
// - 0.3b update to vhdl style guideline
// - 0.3 Add Multi-Lane support
// - 0.2 FIX behaviour when valid is oscillating
// - 0.1 first release

`timescale 1ns/1ps

module aurora_st_decoder #(
  parameter int unsigned g_N_LANES    = 1,
  parameter int unsigned g_FIFO_WORDS = 8,
  // Pad width below. Same lane count and different widths must not share one C++ type.
  parameter int unsigned g_LANE_WIDTH = 32
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic snk_link_up_i,
  input  logic [colibri_aurora_const::c_AURORA_ENC_WIDTH-1:0] snk_data_i [0:g_N_LANES-1],
  input  logic snk_valid_i,
  output logic snk_ready_o,
  output logic src_sop_o,
  output logic src_eop_o,
  output logic src_valid_o,
  output logic src_error_o,
  output logic [colibri_aurora_const::c_AURORA_DATA_WIDTH-1:0] src_data_o,
  output logic [colibri_utils::log2ceil(colibri_aurora_const::c_AURORA_DATA_WIDTH / 8)-1:0] src_empty_o
);

  localparam int c_DATA_W    = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W     = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_EMPTY_W   = colibri_utils::log2ceil(c_DATA_W / 8);
  localparam int c_SHIFT16_W = c_DATA_W - 16;
  localparam int c_SHIFT8_W  = c_DATA_W - 8;
  localparam int c_HEADER_HI = colibri_aurora_const::c_HEADER_HI;
  localparam int c_HEADER_LO = colibri_aurora_const::c_HEADER_LO;
  localparam int c_CTRL_HI   = colibri_aurora_const::c_CTRL_HI;
  localparam int c_CTRL_LO   = colibri_aurora_const::c_CTRL_LO;
  localparam int c_VALID_HI  = colibri_aurora_const::c_VALID_HI;
  localparam int c_VALID_LO  = colibri_aurora_const::c_VALID_LO;
  localparam int c_VALID_W   = c_VALID_HI - c_VALID_LO + 1;
  localparam int c_BOND_W    = 18;
  localparam int c_LANES_W   = c_ENC_W * g_N_LANES;
  localparam logic [c_BOND_W-1:0] c_BOND_TAG = {
    colibri_aurora_const::c_CTRL_SH,
    colibri_aurora_const::c_IDLE_CB_BLOCK,
    colibri_aurora_const::c_CB_CODE
  };

  typedef enum logic [2:0] {
    S_RESET,
    S_IDLE,
    S_WAIT_SEP,
    S_DATA,
    S_WAIT_EOP
  } fsm_t;

  typedef struct {
    fsm_t                    state;
    int unsigned             lanes_ptr;
    logic [c_ENC_W-1:0]      idata;
    logic                    ivalid;
    logic                    iready;
    logic [c_DATA_W-1:0]     odata;
    logic                    valid;
    logic                    lookahead;
    logic                    sop;
    logic                    eop;
    logic                    error;
    logic [c_EMPTY_W-1:0]    empty;
    logic [g_LANE_WIDTH-1:0] lane_pad;
  } sig_t;

  sig_t rreg;
  sig_t rcmb;

  logic [c_ENC_W-1:0]   ififo_data [0:g_N_LANES-1];
  logic [c_LANES_W-1:0] ififo_slv;
  logic [c_ENC_W-1:0]   ofifo_data [0:g_N_LANES-1];
  logic [c_LANES_W-1:0] ofifo_slv;
  logic                 ofifo_valid;
  logic                 fifo_empty;
  logic                 fifo_full;
  logic                 filter_valid;
  logic                 ch_bond_lane0;
  logic                 fifo_rdreq;

  function automatic sig_t fsm_init();
    sig_t v_init;
    v_init.state     = S_RESET;
    v_init.lanes_ptr = 0;
    v_init.idata     = '0;
    v_init.ivalid    = 1'b0;
    v_init.iready    = 1'b0;
    v_init.odata     = '0;
    v_init.valid     = 1'b0;
    v_init.lookahead = 1'b0;
    v_init.sop       = 1'b0;
    v_init.eop       = 1'b0;
    v_init.error     = 1'b0;
    v_init.empty     = '0;
    v_init.lane_pad  = '0;
    return v_init;
  endfunction

  function automatic logic [c_EMPTY_W-1:0] empty_from_valid(
    input logic [c_VALID_W-1:0] v_valid_blocks
  );
    int v_empty_num;
    v_empty_num = (c_DATA_W / 8) - int'(v_valid_blocks);
    return c_EMPTY_W'(v_empty_num);
  endfunction

  // bits#(48) and bits#(56) swap_endianness hit a Verilator 5.020 C++ bug.
  // Byte order matches colibri_utils::bits#(W)::swap_endianness.
  function automatic logic [c_SHIFT16_W-1:0] swap48(input logic [c_SHIFT16_W-1:0] vec);
    return {vec[7:0], vec[15:8], vec[23:16], vec[31:24], vec[39:32], vec[47:40]};
  endfunction

  function automatic logic [c_SHIFT8_W-1:0] swap56(input logic [c_SHIFT8_W-1:0] vec);
    return {vec[7:0], vec[15:8], vec[23:16], vec[31:24], vec[39:32], vec[47:40], vec[55:48]};
  endfunction

  // The VHDL procedure's `reg` argument is unused; the body reads rreg.
  function automatic sig_t parse_ctrl(input sig_t var_in);
    sig_t var_out;
    var_out = var_in;
    if (rreg.state == S_DATA)
      var_out.sop = 1'b1;
    else
      var_out.sop = 1'b0;

    case (rreg.idata[c_CTRL_HI:c_CTRL_LO])
      colibri_aurora_const::c_SEP7_BLOCK: begin
        var_out.valid = 1'b1;
        var_out.eop   = 1'b1;
        var_out.odata = {swap56(rreg.idata[c_SHIFT8_W-1:0]), 8'h00};
        var_out.empty = c_EMPTY_W'(1);
        var_out.state = S_DATA;
      end
      colibri_aurora_const::c_SEP_BLOCK: begin
        if (rreg.idata[c_VALID_HI:c_VALID_LO] != '0) begin
          var_out.valid = 1'b1;
          var_out.eop   = 1'b1;
          var_out.odata = {swap48(rreg.idata[c_SHIFT16_W-1:0]), 16'h00};
          var_out.empty = empty_from_valid(rreg.idata[c_VALID_HI:c_VALID_LO]);
          var_out.state = S_DATA;
        end
      end
      default: begin
        var_out.sop   = 1'b0;
        var_out.valid = 1'b0;
      end
    endcase
    return var_out;
  endfunction

  always_comb begin : proc_filter
    logic [g_N_LANES-1:0] v_valid;
    v_valid      = '0;
    filter_valid = 1'b0;
    if (snk_valid_i) begin
      for (int i = 0; i < g_N_LANES; i++) begin
        if ((snk_data_i[i][c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_CTRL_SH) &&
            (snk_data_i[i][c_CTRL_HI:c_CTRL_LO] == colibri_aurora_const::c_IDLE_CB_BLOCK))
          v_valid[i] = 1'b1;
      end
      if (~(&v_valid))
        filter_valid = 1'b1;
    end
  end

  assign ch_bond_lane0 =
    (snk_data_i[0][c_ENC_W-1 -: c_BOND_W] == c_BOND_TAG) && snk_valid_i;
  assign ififo_data = snk_data_i;
  assign ififo_slv  = colibri_types::slv_arr#(g_N_LANES, c_ENC_W)::to_slv(ififo_data);
  assign ofifo_data = colibri_types::slv_arr#(g_N_LANES, c_ENC_W)::from_slv(ofifo_slv);

  assign fifo_rdreq = rcmb.iready;

  // verilator lint_off PINMISSING
  fifo #(
    .g_NUM_WORDS(int'(g_FIFO_WORDS)),
    .g_INPUT_WIDTH(c_LANES_W),
    .g_OUTPUT_WIDTH(c_LANES_W),
    .g_ENABLE_FWFT(1'b1)
  ) fifo_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .data_i(ififo_slv),
    .wrreq_i(filter_valid),
    .rdreq_i(fifo_rdreq),
    .q_o(ofifo_slv),
    .empty_o(fifo_empty),
    .full_o(fifo_full)
  );
  // verilator lint_on PINMISSING

  assign ofifo_valid = ~fifo_empty;
  assign snk_ready_o = ~fifo_full;

  always_ff @(posedge clk_i) begin : proc_fsm_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int        = rreg;
    v_int.idata  = ofifo_data[rreg.lanes_ptr];
    v_int.ivalid = ofifo_valid;
    v_int.iready = 1'b0;

    if (rreg.valid) begin
      v_int.valid = 1'b0;
      v_int.sop   = 1'b0;
      v_int.eop   = 1'b0;
      v_int.error = rreg.error & ~rreg.eop;
      v_int.empty = '0;
      v_int.odata = '0;
    end

    if (ofifo_valid) begin
      if (rreg.lanes_ptr == g_N_LANES - 1) begin
        v_int.lanes_ptr = 0;
        v_int.iready    = 1'b1;
      end else begin
        v_int.lanes_ptr = rreg.lanes_ptr + 1;
      end
    end else begin
      v_int.iready = 1'b1;
    end

    case (rreg.state)
      S_RESET: begin
        v_int.state = S_IDLE;
      end
      S_IDLE: begin
        v_int.valid = 1'b0;
        v_int.sop   = 1'b0;
        v_int.eop   = 1'b0;
        if (snk_link_up_i)
          v_int.state = S_WAIT_SEP;
      end
      S_WAIT_SEP: begin
        v_int.valid = 1'b0;
        v_int.sop   = 1'b0;
        v_int.eop   = 1'b0;
        if (rreg.ivalid &&
            (rreg.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_CTRL_SH) &&
            ((rreg.idata[c_CTRL_HI:c_CTRL_LO] == colibri_aurora_const::c_SEP7_BLOCK) ||
             (rreg.idata[c_CTRL_HI:c_CTRL_LO] == colibri_aurora_const::c_SEP_BLOCK)))
          v_int.state = S_DATA;
        if (!snk_link_up_i)
          v_int.state = S_WAIT_SEP;
      end
      S_DATA: begin
        v_int.eop = 1'b0;
        if (rreg.ivalid) begin
          v_int.valid = 1'b0;
          if (rreg.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_DATA_SH) begin
            v_int.odata     = colibri_utils::bits#(c_DATA_W)::swap_endianness(rreg.idata[c_DATA_W-1:0]);
            v_int.sop       = 1'b1;
            v_int.lookahead = 1'b1;
          end else if (rreg.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_CTRL_SH) begin
            v_int = parse_ctrl(v_int);
          end
        end
        if (v_int.lookahead && v_int.ivalid) begin
          v_int.valid     = 1'b1;
          v_int.lookahead = 1'b0;
          if ((v_int.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_CTRL_SH) &&
              (v_int.idata[c_CTRL_HI:c_CTRL_LO] == colibri_aurora_const::c_SEP_BLOCK) &&
              (v_int.idata[c_VALID_HI:c_VALID_LO] == '0))
            v_int.eop = 1'b1;
          else
            v_int.state = S_WAIT_EOP;
        end
      end
      S_WAIT_EOP: begin
        v_int.sop = 1'b0;
        if (rreg.ivalid) begin
          v_int.valid = 1'b0;
          if (rreg.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_DATA_SH) begin
            v_int.odata     = colibri_utils::bits#(c_DATA_W)::swap_endianness(rreg.idata[c_DATA_W-1:0]);
            v_int.lookahead = 1'b1;
          end else if (rreg.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_CTRL_SH) begin
            v_int = parse_ctrl(v_int);
          end
        end
        if (v_int.lookahead && v_int.ivalid) begin
          v_int.valid     = 1'b1;
          v_int.lookahead = 1'b0;
          if ((v_int.idata[c_HEADER_HI:c_HEADER_LO] == colibri_aurora_const::c_CTRL_SH) &&
              (v_int.idata[c_CTRL_HI:c_CTRL_LO] == colibri_aurora_const::c_SEP_BLOCK) &&
              (v_int.idata[c_VALID_HI:c_VALID_LO] == '0)) begin
            v_int.eop   = 1'b1;
            v_int.state = S_DATA;
          end
        end
      end
      default: begin
      end
    endcase

    if (!snk_link_up_i && ((rreg.state == S_DATA) || (rreg.state == S_WAIT_EOP))) begin
      v_int.eop   = 1'b1;
      v_int.valid = 1'b1;
      v_int.error = 1'b1;
      v_int.state = S_WAIT_SEP;
    end

    if (snk_link_up_i && (g_N_LANES == 1) && ch_bond_lane0)
      v_int.error = 1'b1;

    if (reset_i)
      v_int = fsm_init();

    rcmb = v_int;
  end

  assign src_data_o  = rreg.odata;
  assign src_valid_o = rreg.valid;
  assign src_sop_o   = rreg.sop;
  assign src_eop_o   = rreg.eop;
  assign src_error_o = rreg.error;
  assign src_empty_o = rreg.empty;

endmodule
