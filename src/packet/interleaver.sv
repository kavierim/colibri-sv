// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Interleaves Avalon-ST streams into one stream and tags the source with
// src_channel_o. Packets already in flight win; otherwise the grant rotates.
// g_INTERLEAVE_WORDS selects word interleaving or whole-packet boundaries.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module interleaver #(
  parameter int unsigned g_NUM_INPUTS       = 3,
  parameter int unsigned g_DATA_WIDTH       = 32,
  parameter bit          g_INTERLEAVE_WORDS = 1'b1,
  localparam int c_DATA_W  = int'(g_DATA_WIDTH),
  localparam int c_CH_W    = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_INPUTS))),
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, 8)
) (
  input  logic                         clk_i,
  input  logic                         reset_i,
  input  logic [g_NUM_INPUTS-1:0]      snk_sop_i,
  input  logic [g_NUM_INPUTS-1:0]      snk_eop_i,
  input  logic [g_NUM_INPUTS-1:0]      snk_valid_i,
  output logic [g_NUM_INPUTS-1:0]      snk_ready_o,
  // Packed, not an unpacked array. An unpacked array input is copied once
  // at reset under this simulator, so later beats stay zero.
  input  logic [g_NUM_INPUTS*c_DATA_W-1:0]  snk_data_i,
  input  logic [g_NUM_INPUTS*c_EMPTY_W-1:0] snk_empty_i,
  output logic                         src_sop_o,
  output logic                         src_eop_o,
  output logic                         src_valid_o,
  input  logic                         src_ready_i,
  output logic [c_DATA_W-1:0]          src_data_o,
  output logic [c_EMPTY_W-1:0]         src_empty_o,
  output logic [c_CH_W-1:0]            src_channel_o
);

  localparam int c_NO_CHANNEL  = int'(g_NUM_INPUTS);
  // Wide enough for the "no channel" code. An int field in this packed
  // struct makes Verilator compare the whole record.
  localparam int c_SEL_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_NO_CHANNEL + 1));
  localparam int c_PIPE_W      = c_DATA_W + c_CH_W;
  localparam int c_PIPE_KEEP_W = colibri_utils::downto_width(c_PIPE_W / 8);

  // VHDL record field `priority` is a SystemVerilog keyword.
  typedef struct packed {
    logic [g_NUM_INPUTS-1:0] ready;
    logic [g_NUM_INPUTS-1:0] inpacket;
    logic [g_NUM_INPUTS-1:0] rr_priority;
    logic [c_SEL_W-1:0]      channel;
  } reg_signals_t;

  function automatic reg_signals_t reg_init();
    reg_signals_t v;
    v.ready       = '0;
    v.inpacket    = '0;
    v.rr_priority = '0;
    v.rr_priority[0] = 1'b1;
    v.channel     = c_SEL_W'(c_NO_CHANNEL);
    return v;
  endfunction

  function automatic logic [c_SEL_W-1:0] select_channel(
    input logic [g_NUM_INPUTS-1:0] valid,
    input logic [g_NUM_INPUTS-1:0] inpacket,
    input logic [g_NUM_INPUTS-1:0] rr_priority
  );
    for (int i = 0; i < g_NUM_INPUTS; i++) begin
      if (valid[i] == 1'b1 && inpacket[i] == 1'b1)
        return c_SEL_W'(i);
    end
    for (int i = 0; i < g_NUM_INPUTS; i++) begin
      if (valid[i] == 1'b1 && rr_priority[i] == 1'b1)
        return c_SEL_W'(i);
    end
    for (int i = 0; i < g_NUM_INPUTS; i++) begin
      if (valid[i] == 1'b1)
        return c_SEL_W'(i);
    end
    return c_SEL_W'(c_NO_CHANNEL);
  endfunction

  function automatic logic [g_NUM_INPUTS-1:0] rotate_priority(
    input logic [g_NUM_INPUTS-1:0] value
  );
    logic [g_NUM_INPUTS-1:0] rotated;
    for (int k = 0; k < g_NUM_INPUTS; k++)
      rotated[(k + 1) % int'(g_NUM_INPUTS)] = value[k];
    return rotated;
  endfunction

  reg_signals_t rreg;
  reg_signals_t rcmb;

  logic                    int_sop;
  logic                    int_eop;
  logic                    int_valid;
  logic                    int_ready;
  logic [c_PIPE_W-1:0]     int_data;
  logic [c_PIPE_W-1:0]     piped_data;
  logic [c_EMPTY_W-1:0]    int_empty;
  logic [c_PIPE_KEEP_W-1:0] snk_keep_tie;
  // VHDL leaves pipeline_buffer.src_keep_o open.
  // verilator lint_off UNUSEDSIGNAL
  logic [c_PIPE_KEEP_W-1:0] src_keep_unused;
  // verilator lint_on UNUSEDSIGNAL

  initial rreg = reg_init();

  assign snk_keep_tie = '0;

  always_ff @(posedge clk_i) begin : proc_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_main_cmb
    reg_signals_t v_int;
    v_int = rreg;

    if (g_INTERLEAVE_WORDS)
      v_int.channel = c_SEL_W'(c_NO_CHANNEL);

    v_int.ready = '0;

    if (int_ready) begin
      if (g_INTERLEAVE_WORDS) begin
        v_int.channel = select_channel(snk_valid_i, rreg.inpacket, rreg.rr_priority);
      end else if (rreg.channel != c_SEL_W'(c_NO_CHANNEL) && rreg.inpacket[rreg.channel] == 1'b1) begin
        v_int.channel = rreg.channel;
      end else begin
        v_int.channel = select_channel(snk_valid_i, rreg.inpacket, rreg.rr_priority);
      end

      if (v_int.channel != c_SEL_W'(c_NO_CHANNEL))
        v_int.ready[v_int.channel] = 1'b1;
      else
        v_int.ready = rreg.rr_priority;

      if (v_int.channel != c_SEL_W'(c_NO_CHANNEL) && snk_valid_i[v_int.channel] == 1'b1) begin
        if (snk_eop_i[v_int.channel] == 1'b1) begin
          v_int.inpacket[v_int.channel] = 1'b0;
          v_int.rr_priority = rotate_priority(rreg.rr_priority);
        end else if (snk_sop_i[v_int.channel] == 1'b1) begin
          v_int.inpacket[v_int.channel] = 1'b1;
        end
      end
    end

    if (reset_i)
      v_int = reg_init();

    rcmb = v_int;
  end

  assign snk_ready_o = rcmb.ready;

  // Constant channel index. A variable select of snk_data_i reads as zero
  // under Verilator 5.020.
  logic [c_DATA_W-1:0]  ch_data  [0:g_NUM_INPUTS-1];
  logic [c_EMPTY_W-1:0] ch_empty [0:g_NUM_INPUTS-1];
  logic [g_NUM_INPUTS-1:0] ch_hit;
  logic [g_NUM_INPUTS-1:0] ch_sop;
  logic [g_NUM_INPUTS-1:0] ch_eop;
  logic [g_NUM_INPUTS-1:0] ch_valid;

  for (genvar gi = 0; gi < g_NUM_INPUTS; gi++) begin : gen_pick
    assign ch_hit[gi]   = (rcmb.channel == c_SEL_W'(gi));
    assign ch_data[gi]  = ch_hit[gi] ? snk_data_i[gi*c_DATA_W +: c_DATA_W] : '0;
    assign ch_empty[gi] = ch_hit[gi] ? snk_empty_i[gi*c_EMPTY_W +: c_EMPTY_W] : '0;
    assign ch_sop[gi]   = ch_hit[gi] && snk_sop_i[gi];
    assign ch_eop[gi]   = ch_hit[gi] && snk_eop_i[gi];
    assign ch_valid[gi] = ch_hit[gi] && snk_valid_i[gi];
  end

  // Constant-index OR. An unpacked reduction array does not reach
  // the pipeline input under this simulator.
  logic [c_DATA_W-1:0]  mux_data;
  logic [c_EMPTY_W-1:0] mux_empty;
  if (g_NUM_INPUTS == 3) begin : gen_or3
    assign mux_data  = ch_data[0] | ch_data[1] | ch_data[2];
    assign mux_empty = ch_empty[0] | ch_empty[1] | ch_empty[2];
  end else begin : gen_or_n
    always_comb begin
      mux_data  = '0;
      mux_empty = '0;
      for (int i = 0; i < g_NUM_INPUTS; i++) begin
        mux_data  = mux_data | ch_data[i];
        mux_empty = mux_empty | ch_empty[i];
      end
    end
  end

  assign int_sop   = |ch_sop;
  assign int_eop   = |ch_eop;
  assign int_valid = |ch_valid;
  assign int_empty = mux_empty;
  assign int_data  = {
    (rcmb.channel == c_SEL_W'(c_NO_CHANNEL)) ? {c_CH_W{1'b0}} : c_CH_W'(rcmb.channel),
    mux_data
  };

  pipeline_buffer #(
    .g_DATA_WIDTH (c_PIPE_W)
  ) pipeline_buffer_inst (
    .clk_i       (clk_i),
    .reset_i     (reset_i),
    .snk_data_i  (int_data),
    .snk_empty_i (int_empty),
    .snk_keep_i  (snk_keep_tie),
    .snk_sop_i   (int_sop),
    .snk_eop_i   (int_eop),
    .snk_valid_i (int_valid),
    .snk_ready_o (int_ready),
    .src_data_o  (piped_data),
    .src_empty_o (src_empty_o),
    .src_keep_o  (src_keep_unused),
    .src_sop_o   (src_sop_o),
    .src_eop_o   (src_eop_o),
    .src_valid_o (src_valid_o),
    .src_ready_i (src_ready_i)
  );

  assign src_data_o    = piped_data[c_DATA_W-1:0];
  assign src_channel_o = piped_data[c_PIPE_W-1 -: c_CH_W];

endmodule
// verilator lint_on MULTITOP
