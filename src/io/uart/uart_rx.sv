// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// UART receiver module
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 20-03-2024
// Version: 0.1
//
// This module implements a simple uart receiver.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module uart_rx #(
  parameter time g_CLOCK_PERIOD = time'(100ns),
  parameter int unsigned g_BAUD_RATE = 115200
) (
  input  logic       clk_i,
  input  logic       reset_i,
  // AXIS receive
  output logic [7:0] rx_data_o,
  output logic       rx_valid_o,
  input  logic       rx_pin_i
);

  // VHDL integer((1 sec / g_BAUD_RATE) / g_CLOCK_PERIOD) truncates at 1 fs.
  // A time/time quotient rounds under this toolchain, so the division is done
  // in integer femtoseconds. g_CLOCK_PERIOD stays parameter time; under
  // timescale 1ns/1ps it is an integer number of picoseconds.
  localparam longint c_CLK_FS = longint'(g_CLOCK_PERIOD / 1ps) * 1000;
  localparam int c_SER_CYCLES =
    int'((64'sd1_000_000_000_000_000 / longint'(g_BAUD_RATE)) / c_CLK_FS);
  localparam int c_DELAY_W = colibri_utils::downto_width(c_SER_CYCLES / 4);

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
    logic       valid;
    logic       clk_en;
    logic [7:0] data_byte;
    logic [3:0] count;
  } sig_t;

  localparam sig_t c_FSM_INIT = '{
    state:     S_IDLE,
    valid:     1'b0,
    clk_en:    1'b0,
    data_byte: '0,
    count:     '0
  };

  // SDC constraints for Altera
  // SDC constraints for Xilinx
  (* preserve = "TRUE" *)
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  (* async_reg = "TRUE" *)
  logic rx_d;
  logic rx_reg;
  sig_t rreg = c_FSM_INIT;
  sig_t rcmb;
  logic serclk;
  logic dataclk;
  logic dataclk_rising;
  int unsigned clk_count = 0;
  logic [c_DELAY_W-1:0] clk_delay;

  always_ff @(posedge clk_i) begin : proc_synch
    if (reset_i) begin
      rx_d   <= 1'b1;
      rx_reg <= 1'b1;
    end else begin
      rx_d   <= rx_pin_i;
      rx_reg <= rx_d;
    end
  end

  always_ff @(posedge clk_i) begin : proc_clk_gen
    if (reset_i) begin
      clk_delay      <= '0;
      clk_count      <= 0;
      dataclk_rising <= 1'b0;
      serclk         <= 1'b0;
      dataclk        <= 1'b0;
    end else begin
      // internal counter for clock division
      if (rreg.clk_en) begin
        clk_delay <= {serclk, clk_delay[c_DELAY_W-1:1]};
        if (clk_count == c_SER_CYCLES / 2 - 1) begin
          clk_count <= 0;
          serclk    <= ~serclk;
        end else begin
          clk_count <= clk_count + 1;
        end
      end else begin
        clk_count <= 0;
        serclk    <= 1'b1;
        clk_delay <= '0;
      end
      // rising edge pulse to capture data
      if (clk_delay[0] && !dataclk)
        dataclk_rising <= 1'b1;
      else
        dataclk_rising <= 1'b0;
      dataclk <= clk_delay[0];
    end
  end

  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int = rreg;

    case (rreg.state)
      S_RESET: begin
        v_int = c_FSM_INIT;
      end

      S_IDLE: begin
        v_int.count = '0;
        // start bit seen
        if (!rx_reg) begin
          v_int.clk_en = 1'b1;
          v_int.state  = S_START;
        end
      end

      S_START: begin
        if (dataclk_rising && !rx_reg) begin
          v_int.count     = rreg.count + 4'(1);
          v_int.data_byte = {rx_reg, rreg.data_byte[7:1]};
          v_int.state     = S_DATA;
        end
      end

      S_DATA: begin
        if (dataclk_rising) begin
          v_int.data_byte = {rx_reg, rreg.data_byte[7:1]};
          if (rreg.count == 4'd8) begin
            v_int.valid = 1'b1;
            v_int.state = S_STOP;
          end else begin
            v_int.count = rreg.count + 4'(1);
          end
        end
      end

      S_STOP: begin
        v_int.valid = 1'b0;
        if (dataclk_rising) begin
          v_int.clk_en = 1'b0;
          v_int.state  = S_IDLE;
        end
      end

      default: begin
      end
    endcase

    if (reset_i)
      v_int.state = S_RESET;

    rcmb = v_int;
  end

  assign rx_data_o  = rreg.data_byte;
  assign rx_valid_o = rreg.valid;

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

endmodule
