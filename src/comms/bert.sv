// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Bit error rate tester. A PRBS scrambler feeds the DUT; g_DUT_DELAY absorbs
// the loopback latency before statistics are counted.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */

module bert #(
  parameter int unsigned g_DATA_WIDTH = 32,
  parameter int unsigned g_STATS_WIDTH = 64,
  parameter g_PRBS_POLY = colibri_poly::c_PRBS_7,
  parameter int unsigned g_DUT_DELAY = 1
) (
  input  logic                     clk_i,
  input  logic                     reset_i,
  input  logic [g_DATA_WIDTH-1:0]  snk_data_i,
  input  logic                     snk_valid_i,
  output logic [g_DATA_WIDTH-1:0]  src_data_o,
  output logic                     src_valid_o,
  output logic [g_STATS_WIDTH-1:0] bit_errors_o,
  output logic [g_STATS_WIDTH-1:0] total_bits_o,
  output logic [g_STATS_WIDTH-1:0] word_errors_o,
  output logic [g_STATS_WIDTH-1:0] invalid_words_o
);

  typedef enum logic [1:0] {
    S_RESET,
    S_START,
    S_COUNT
  } fsm_t;

  typedef struct packed {
    fsm_t                        state;
    int unsigned                 delay;
    logic                        valid;
    int unsigned                 bit_flip;
    logic [g_STATS_WIDTH-1:0]    invalid_words;
    logic [g_STATS_WIDTH-1:0]    word_errors;
    logic [g_STATS_WIDTH-1:0]    total_bit_flip;
    logic [g_STATS_WIDTH-1:0]    total_bits;
  } sig_t;

  localparam sig_t c_FSM_INIT = '{
    state:          S_RESET,
    delay:          0,
    valid:          1'b0,
    bit_flip:       0,
    invalid_words:  '0,
    word_errors:    '0,
    total_bit_flip: '0,
    total_bits:     '0
  };

  logic [g_DATA_WIDTH-1:0] c_PRBS_SIGNATURE;
  sig_t                    rreg = c_FSM_INIT;
  sig_t                    rcmb;
  logic [g_DATA_WIDTH-1:0] delay_buf [0:g_DUT_DELAY-1];

  // Even indexes are 1, matching bits#(W)::gen_even. Kept local so a data
  // width that is not a multiple of 8 does not specialize that class.
  function automatic logic [g_DATA_WIDTH-1:0] gen_even_word;
    logic [g_DATA_WIDTH-1:0] v_ret;
    for (int i = 0; i < g_DATA_WIDTH; i++)
      v_ret[i] = ~i[0];
    return v_ret;
  endfunction

  assign c_PRBS_SIGNATURE = gen_even_word();

  scrambler #(
    .g_DATA_WIDTH(g_DATA_WIDTH),
    .g_SCRAMBLER_POLY(g_PRBS_POLY)
  ) scrambler_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .snk_data_i(c_PRBS_SIGNATURE),
    .snk_valid_i(1'b1),
    // VHDL leaves this ready open.
    /* verilator lint_off PINCONNECTEMPTY */
    .snk_ready_o(),
    /* verilator lint_on PINCONNECTEMPTY */
    .src_data_o(src_data_o),
    .src_valid_o(src_valid_o),
    .src_ready_i(1'b1)
  );

  // g_DUT_DELAY of 1 is a single register. The shift loop would compare
  // against 0 and Verilator treats that unsigned compare as constant.
  if (int'(g_DUT_DELAY) <= 1) begin : gen_delay_one
    always_ff @(posedge clk_i) begin : proc_delay_word
      delay_buf[0] <= src_data_o;
    end
  end else begin : gen_delay_many
    always_ff @(posedge clk_i) begin : proc_delay_word
      for (int i = 0; i < int'(g_DUT_DELAY) - 1; i++)
        delay_buf[i] <= delay_buf[i+1];
      delay_buf[g_DUT_DELAY-1] <= src_data_o;
    end
  end

  always_ff @(posedge clk_i) begin : proc_fsm_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int = rreg;

    case (rreg.state)
      S_RESET: begin
        v_int.state = S_START;
      end
      S_START: begin
        v_int.bit_flip = int'($countones(snk_data_i ^ delay_buf[0]));
        v_int.delay    = rreg.delay + 1;
        v_int.valid    = snk_valid_i;
        if (rreg.delay == g_DUT_DELAY) begin
          v_int.state = S_COUNT;
          v_int.delay = 0;
        end
      end
      S_COUNT: begin
        v_int.bit_flip   = int'($countones(snk_data_i ^ delay_buf[0]));
        v_int.valid      = snk_valid_i;
        v_int.total_bits = rreg.total_bits + g_STATS_WIDTH'(g_DATA_WIDTH);
        if (rreg.valid) begin
          v_int.total_bit_flip = rreg.total_bit_flip + g_STATS_WIDTH'(rreg.bit_flip);
          if (rreg.bit_flip != 0)
            v_int.word_errors = rreg.word_errors + g_STATS_WIDTH'(1);
        end else begin
          v_int.invalid_words = rreg.invalid_words + g_STATS_WIDTH'(1);
        end
      end
      // Encoding 2'd3 is not a VHDL state.
      default: v_int.state = rreg.state;
    endcase

    if (reset_i)
      v_int = c_FSM_INIT;

    rcmb = v_int;
  end

  assign total_bits_o    = rreg.total_bits;
  assign bit_errors_o    = rreg.total_bit_flip;
  assign word_errors_o   = rreg.word_errors;
  assign invalid_words_o = rreg.invalid_words;

endmodule
