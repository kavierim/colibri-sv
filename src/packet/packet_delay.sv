// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Delays Avalon-ST packets by delay_i clock cycles, counted from the input
// start-of-packet handshake. Up to g_N_PACKETS packets can be in flight.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module packet_delay #(
  parameter int unsigned g_SYM_WIDTH   = 8,
  parameter int unsigned g_DATA_SYM    = 4,
  parameter int unsigned g_N_PACKETS   = 3,
  parameter int unsigned g_NUM_BEATS   = 8,
  parameter int unsigned g_DELAY_WIDTH = 4,
  localparam int c_DATA_W  = int'(g_DATA_SYM) * int'(g_SYM_WIDTH),
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, int'(g_SYM_WIDTH))
) (
  input  logic                      clk_i,
  input  logic                      reset_i,
  input  logic [g_DELAY_WIDTH-1:0]  delay_i,
  input  logic [c_DATA_W-1:0]       snk_data_i,
  input  logic [c_EMPTY_W-1:0]      snk_empty_i,
  input  logic                      snk_sop_i,
  input  logic                      snk_eop_i,
  input  logic                      snk_valid_i,
  output logic                      snk_ready_o,
  output logic [c_DATA_W-1:0]       src_data_o,
  output logic [c_EMPTY_W-1:0]      src_empty_o,
  output logic                      src_sop_o,
  output logic                      src_eop_o,
  output logic                      src_valid_o,
  input  logic                      src_ready_i
);

  // 2**g_DELAY_WIDTH - 2, without shifting a 32-bit literal off the end.
  localparam logic [g_DELAY_WIDTH-1:0] c_CNT_STOP = {g_DELAY_WIDTH{1'b1}} - g_DELAY_WIDTH'(1);

  typedef struct packed {
    logic                   hold_input;
    logic                   hold_output;
    int                     cnt_idx;
    int                     next_cnt_idx;
    logic [g_N_PACKETS-1:0] cnt_reset;
    logic [g_N_PACKETS-1:0] cnt_enable;
  } reg_t;

  function automatic reg_t reg_init();
    reg_t v;
    v.hold_input   = 1'b0;
    v.hold_output  = 1'b1;
    v.cnt_idx      = 0;
    v.next_cnt_idx = 0;
    v.cnt_reset    = '0;
    v.cnt_enable   = '0;
    return v;
  endfunction

  reg_t r;
  reg_t rin;
  logic fifo_ready;
  logic fifo_valid;
  logic [g_DELAY_WIDTH-1:0] delay_cnt [0:g_N_PACKETS-1];

  // VHDL leaves counter.wraparound_o open.
  // verilator lint_off UNUSEDSIGNAL
  logic [g_N_PACKETS-1:0] cnt_wrap_unused;
  // verilator lint_on UNUSEDSIGNAL

  initial r = reg_init();

  avst_fifo #(
    .g_SYM_WIDTH    (g_SYM_WIDTH),
    .g_DATA_SYM     (g_DATA_SYM),
    .g_NUM_BEATS    (g_NUM_BEATS),
    .g_ASYNC_CLOCKS (1'b0)
  ) u_avst_fifo (
    .snk_clk_i   (clk_i),
    .src_clk_i   (clk_i),
    .snk_reset_i (reset_i),
    .snk_ready_o (fifo_ready),
    .snk_valid_i (snk_valid_i & ~r.hold_input),
    .snk_sop_i   (snk_sop_i),
    .snk_eop_i   (snk_eop_i),
    .snk_empty_i (snk_empty_i),
    .snk_data_i  (snk_data_i),
    .src_ready_i (src_ready_i & ~r.hold_output),
    .src_valid_o (fifo_valid),
    .src_sop_o   (src_sop_o),
    .src_eop_o   (src_eop_o),
    .src_empty_o (src_empty_o),
    .src_data_o  (src_data_o)
  );

  assign snk_ready_o = fifo_ready & ~r.hold_input;
  assign src_valid_o = fifo_valid & ~r.hold_output;

  for (genvar i = 0; i < g_N_PACKETS; i++) begin : gen_counters
    counter #(
      .g_COUNTER_WIDTH (g_DELAY_WIDTH)
    ) u_counter (
      .clk_i        (clk_i),
      .reset_i      (reset_i | r.cnt_reset[i]),
      .enable_i     (r.cnt_enable[i]),
      .value_o      (delay_cnt[i]),
      .wraparound_o (cnt_wrap_unused[i])
    );
  end

  always_comb begin : proc_comb
    reg_t v;
    logic [g_DELAY_WIDTH-1:0] delay_m1;

    v = r;
    v.cnt_reset = '0;
    delay_m1 = delay_i - g_DELAY_WIDTH'(1);

    if (snk_sop_i && snk_valid_i && snk_ready_o) begin
      v.cnt_enable[r.next_cnt_idx] = 1'b1;
      if (r.next_cnt_idx == int'(g_N_PACKETS) - 1)
        v.next_cnt_idx = 0;
      else
        v.next_cnt_idx = r.next_cnt_idx + 1;
    end

    if (src_eop_o && src_valid_o && src_ready_i) begin
      if (r.cnt_idx == int'(g_N_PACKETS) - 1)
        v.cnt_idx = 0;
      else
        v.cnt_idx = r.cnt_idx + 1;
      v.hold_output = 1'b1;
    end

    // Delay 0 releases only an active slot. Applying it to an idle slot
    // clears hold_output while the counters match and locks the input.
    if (((r.cnt_enable[v.cnt_idx] == 1'b1) || (delay_cnt[v.cnt_idx] != '0))
        && ((delay_i == '0) || (delay_cnt[v.cnt_idx] >= delay_m1))) begin
      v.hold_output          = 1'b0;
      v.cnt_enable[v.cnt_idx] = 1'b0;
      v.cnt_reset[v.cnt_idx]  = 1'b1;
    end

    v.hold_input = colibri_types::bool_to_sl(bit'(v.next_cnt_idx == v.cnt_idx))
                   & ((~v.hold_output) | v.cnt_enable[v.cnt_idx]);

    for (int i = 0; i < g_N_PACKETS; i++) begin
      if (delay_cnt[i] == c_CNT_STOP)
        v.cnt_enable[i] = 1'b0;
    end

    if (reset_i)
      v = reg_init();

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_reg
    r <= rin;
  end

endmodule
// verilator lint_on MULTITOP
