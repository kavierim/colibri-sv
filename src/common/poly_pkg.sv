// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// VHDL package `poly` (file poly_pkg.vhdl) is SystemVerilog package `colibri_poly`.

`timescale 1ns/1ps

package colibri_poly;

  // Common CRC polynomials.
  localparam logic [0:0]  c_CRC_1        = 1'b1;
  localparam logic [2:0]  c_CRC_3_GSM    = 3'h3;
  localparam logic [4:0]  c_CRC_5_USB    = 5'h05;
  localparam logic [7:0]  c_CRC_8        = 8'h07;
  localparam logic [15:0] c_CRC_16_CCITT = 16'h1021;
  localparam logic [31:0] c_CRC_32       = 32'h04c11db7;

  // Common scrambling polynomials.
  localparam logic [57:0] c_SCR_10GBASE = 58'h80001;

  // Common PRBS polynomials.
  localparam logic [5:0]  c_PRBS_5  = 6'h29;
  localparam logic [7:0]  c_PRBS_7  = 8'hc1;
  localparam logic [15:0] c_PRBS_15 = 16'hc001;
  localparam logic [23:0] c_PRBS_23 = 24'h840001;
  localparam logic [31:0] c_PRBS_31 = 32'h90000001;

endpackage
