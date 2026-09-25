// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// JTAG stream serializer/deserializer
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 15-12-2025 Created
// Version: 0.1
// Copyright CERN 2025
//
// This component converts a simple jtag interface with additional FSM signals
// (shift, update) into a streaming duplex interface with configurable data width.
// The entity has been designed to work with JTAG primitives available from vendors
// to create a vendor-independent direct interface with user logic.

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module jtag_serdes #(
  parameter int unsigned g_DATA_WIDTH = 8,
  parameter bit g_REG_FALLING = 1'b0
) (
  // clocks
  input  logic clk_ser_i,
  input  logic clk_par_i,
  // jtag FSM states (on clk_ser_i)
  input  logic shift_i,
  input  logic update_i,
  // parallel input stream
  input  logic [colibri_utils::downto_width(int'(g_DATA_WIDTH))-1:0] par_data_i,
  input  logic par_valid_i,
  output logic par_ready_o,
  // parallel output stream
  output logic [colibri_utils::downto_width(int'(g_DATA_WIDTH))-1:0] par_data_o,
  output logic par_valid_o,
  // serial input
  input  logic ser_data_i,
  // serial output
  output logic ser_data_o
);

  localparam int c_DATA_W = colibri_utils::downto_width(int'(g_DATA_WIDTH));

  logic [c_DATA_W-1:0] sp_data;
  logic sp_level;
  logic sp_level_reg;
  logic [c_DATA_W-1:0] ps_data;
  logic [c_DATA_W-1:0] shreg = '0;
  logic upd_level = 1'b0;

  // sticky input to reduce metastability issues
  // sampled at UPDATE (many clock cycles to stabilize)
  always_ff @(posedge clk_par_i) begin : proc_sync_ps
    if (par_valid_i && par_ready_o)
      ps_data <= par_data_i;
  end

  // jtag shifting register
  always_ff @(posedge clk_ser_i) begin : proc_shreg
    if (shift_i) begin
      // VHDL: ser_data_i & shreg(g_DATA_WIDTH-1 downto 1)
      // Shift stays valid when the width is 1 (that VHDL slice is a null range).
      shreg <= (shreg >> 1) | (c_DATA_W'(ser_data_i) << (c_DATA_W - 1));
    end else if (!update_i) begin
      shreg <= ps_data;
    end
  end

  // generate TDO sampling
  if (g_REG_FALLING) begin : gen_falling
    always_ff @(negedge clk_ser_i) begin : proc_tdo_fall
      ser_data_o <= shreg[0];
    end
  end else begin : gen_tdo_level
    assign ser_data_o = shreg[0];
  end

  // update output logic
  always_ff @(posedge update_i) begin : proc_upd_level
    upd_level <= ~upd_level;
  end

  assign sp_data = shreg;

  // synchronize with fast clock
  synchro #(
    .g_DATA_LENGTH(1)
  ) sync_level_inst (
    .clk_i(clk_par_i),
    .reset_i(1'b0),
    .data_i(upd_level),
    .data_o(sp_level)
  );

  // register on fast clock
  always_ff @(posedge clk_par_i) begin : proc_out_data
    par_valid_o  <= 1'b0;
    sp_level_reg <= sp_level;
    if (sp_level_reg ^ sp_level) begin
      par_valid_o <= 1'b1;
      par_data_o  <= sp_data;
    end
  end

  // drive ready back (sample data when shift is completed)
  // needed to plug a fifo in input
  assign par_ready_o = par_valid_o;

endmodule
