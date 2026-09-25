// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// UART Controller module
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 20-03-2024
// Version: 0.1
//
// This module implements a simple uart controller.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module uart #(
  parameter time g_CLOCK_PERIOD = time'(100ns),
  parameter int unsigned g_BAUD_RATE = 115200
) (
  input  logic       clk_i,
  input  logic       reset_i,
  // AXIS transmit
  input  logic [7:0] tx_data_i,
  input  logic       tx_valid_i,
  output logic       tx_ready_o,
  // AXIS receive
  output logic [7:0] rx_data_o,
  output logic       rx_valid_o,
  input  logic       rx_pin_i,
  output logic       tx_pin_o
);

  uart_rx #(
    .g_CLOCK_PERIOD(g_CLOCK_PERIOD),
    .g_BAUD_RATE(g_BAUD_RATE)
  ) uart_rx_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .rx_data_o(rx_data_o),
    .rx_valid_o(rx_valid_o),
    .rx_pin_i(rx_pin_i)
  );

  uart_tx #(
    .g_CLOCK_PERIOD(g_CLOCK_PERIOD),
    .g_BAUD_RATE(g_BAUD_RATE)
  ) uart_tx_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .tx_data_i(tx_data_i),
    .tx_valid_i(tx_valid_i),
    .tx_ready_o(tx_ready_o),
    .tx_pin_o(tx_pin_o)
  );

endmodule
