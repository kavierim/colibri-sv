// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// UART transmitter module
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 20-03-2024
// Version: 0.1
//
// This module implements a simple uart transmitter.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module uart_tx #(
  parameter time g_CLOCK_PERIOD = time'(100ns),
  parameter int unsigned g_BAUD_RATE = 115200
) (
  input  logic       clk_i,
  input  logic       reset_i,
  // AXIS transmit
  input  logic [7:0] tx_data_i,
  input  logic       tx_valid_i,
  output logic       tx_ready_o,
  output logic       tx_pin_o
);

  // VHDL integer((1 sec / g_BAUD_RATE) / g_CLOCK_PERIOD) truncates at 1 fs.
  // A time/time quotient rounds under this toolchain, so the division is done
  // in integer femtoseconds. g_CLOCK_PERIOD stays parameter time; under
  // timescale 1ns/1ps it is an integer number of picoseconds.
  localparam longint c_CLK_FS = longint'(g_CLOCK_PERIOD / 1ps) * 1000;
  localparam int c_SER_CYCLES =
    int'((64'sd1_000_000_000_000_000 / longint'(g_BAUD_RATE)) / c_CLK_FS);

  typedef enum logic [2:0] {
    S_RESET = 3'd0,
    S_IDLE  = 3'd1,
    S_START = 3'd2,
    S_DATA  = 3'd3,
    S_STOP  = 3'd4
  } fsm_t;

  // VHDL record field `byte` is data_byte: `byte` is a SystemVerilog keyword.
  typedef struct packed {
    fsm_t       state;
    logic       tx;
    logic [7:0] data_byte;
    logic [3:0] count;
  } sig_t;

  localparam sig_t c_FSM_INIT = '{
    state:     S_IDLE,
    tx:        1'b1,
    data_byte: '0,
    count:     '0
  };

  int unsigned clk_count = 0;
  sig_t rreg = c_FSM_INIT;
  sig_t rcmb;
  logic serclk;
  logic serclk_rising;

  always_ff @(posedge clk_i) begin : proc_clk_gen
    if (reset_i) begin
      clk_count     <= 0;
      serclk_rising <= 1'b0;
      serclk        <= 1'b0;
    end else begin
      serclk_rising <= 1'b0;
      // internal counter for clock division
      if (clk_count == c_SER_CYCLES / 2 - 1) begin
        clk_count <= 0;
        serclk    <= ~serclk;
        if (!serclk)
          serclk_rising <= 1'b1;
      end else begin
        clk_count <= clk_count + 1;
      end
    end
  end

  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int      = rreg;
    tx_ready_o = 1'b0;

    case (rreg.state)
      S_RESET: begin
        v_int = c_FSM_INIT;
      end

      S_IDLE: begin
        if (serclk_rising) begin
          tx_ready_o = 1'b1;
          if (tx_valid_i) begin
            v_int.data_byte = tx_data_i;
            v_int.tx        = 1'b0;
            v_int.count     = '0;
            v_int.state     = S_START;
          end
        end
      end

      S_START: begin
        if (serclk_rising) begin
          v_int.tx        = rreg.data_byte[0];
          v_int.data_byte = {1'b0, rreg.data_byte[7:1]};
          v_int.count     = rreg.count + 4'(1);
          v_int.state     = S_DATA;
        end
      end

      S_DATA: begin
        if (serclk_rising) begin
          v_int.tx        = rreg.data_byte[0];
          v_int.data_byte = {1'b0, rreg.data_byte[7:1]};
          if (rreg.count == 4'd8) begin
            v_int.tx    = 1'b1;
            v_int.state = S_STOP;
          end else begin
            v_int.count = rreg.count + 4'(1);
          end
        end
      end

      S_STOP: begin
        if (serclk_rising)
          v_int.state = S_IDLE;
      end

      default: begin
      end
    endcase

    if (reset_i)
      v_int.state = S_RESET;

    rcmb = v_int;
  end

  assign tx_pin_o = rreg.tx;

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

endmodule
