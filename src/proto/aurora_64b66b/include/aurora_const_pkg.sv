// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Aurora 64b/66b constants.
// VHDL package `aurora_const` (file aurora_const_pkg.vhdl) is
// SystemVerilog package `colibri_aurora_const`.
// changelog:
// - 0.3 Update to VHDL Style Guide
// - 0.2 Adding Channel Bonding Feature
// - 0.1 first release

`timescale 1ns/1ps

package colibri_aurora_const;

  localparam int c_AURORA_DATA_WIDTH = 64;
  localparam int c_AURORA_ENC_WIDTH  = 66;

  // SYNC HEADERS
  localparam logic [1:0] c_DATA_SH = 2'b01;
  localparam logic [1:0] c_CTRL_SH = 2'b10;

  // CONTROL OCTETS
  localparam logic [7:0] c_IDLE_CB_BLOCK = 8'h78;
  localparam logic [7:0] c_SEP_BLOCK     = 8'h1e;
  localparam logic [7:0] c_SEP7_BLOCK    = 8'he1;

  // VHDL subtype header_range: ENC-1 downto ENC-2
  localparam int c_HEADER_HI = c_AURORA_ENC_WIDTH - 1;
  localparam int c_HEADER_LO = c_AURORA_ENC_WIDTH - 2;

  // VHDL subtype ctrl_block_range: ENC-3 downto ENC-10
  localparam int c_CTRL_HI = c_AURORA_ENC_WIDTH - 3;
  localparam int c_CTRL_LO = c_AURORA_ENC_WIDTH - 10;

  // VHDL subtype valid_block_range: ENC-16 downto ENC-18
  localparam int c_VALID_HI = c_AURORA_ENC_WIDTH - 16;
  localparam int c_VALID_LO = c_AURORA_ENC_WIDTH - 18;

  localparam logic [7:0] c_CB_CODE = 8'h40;

  // c_CTRL_SH & c_IDLE_CB_BLOCK & (DATA-1 downto 8 => '0')
  localparam logic [c_AURORA_ENC_WIDTH-1:0] c_IDLE_WORD =
    {c_CTRL_SH, c_IDLE_CB_BLOCK, {(c_AURORA_DATA_WIDTH - 8){1'b0}}};

  // c_CTRL_SH & c_IDLE_CB_BLOCK & c_CB_CODE & (DATA-1 downto 16 => '0')
  localparam logic [c_AURORA_ENC_WIDTH-1:0] c_CB_WORD =
    {c_CTRL_SH, c_IDLE_CB_BLOCK, c_CB_CODE, {(c_AURORA_DATA_WIDTH - 16){1'b0}}};

  // c_CTRL_SH & c_SEP_BLOCK & (DATA-1 downto 8 => '0')
  localparam logic [c_AURORA_ENC_WIDTH-1:0] c_EMPTY_SEP_WORD =
    {c_CTRL_SH, c_SEP_BLOCK, {(c_AURORA_DATA_WIDTH - 8){1'b0}}};

  // maximum number of idle packets sent before tx ready
  localparam int c_MAX_SYNC_CNT = 64;
  // send channel bond frame every N words (VHDL range 8 to 255)
  localparam int c_CH_BOND_CYCLES = 64;

endpackage
