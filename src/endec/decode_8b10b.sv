// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// 8b/10b Decoder
// lookup table (ROM)-based 8b/10b decoder.
// The lookup table approach guarantees minimal resource usage and short combinatorial paths.
// copyright CERN 2025
//
// Changelog:
// - 0.2 reformatted for Vivado to infer primitives

`timescale 1ns/1ps

// Library entity. Lint alongside verilator/wave0_elab.sv reports multiple tops.
// verilator lint_off MULTITOP
module decode_8b10b (
  input  logic       clk_i,
  input  logic [9:0] snk_data_i,
  input  logic       snk_valid_i,
  output logic [7:0] src_data_o,
  output logic       src_control_o, // is K code
  output logic       src_valid_o
);

  logic [9:0] reg_dec;
  logic       reg_valid = 1'b0;
  logic       reg_rd    = 1'b0;

  // decoding ROM: declaration required for vivado to infer ROM primitives
  logic [9:0] decoding_rom [0:1023] = colibri_common_8b10b::c_DECODE_ROM_8B10B;

  // two stage architecture
  always_ff @(posedge clk_i) begin : proc_main
    reg_valid <= snk_valid_i;
    // 1. read from rom and register
    if (snk_valid_i)
      reg_dec <= decoding_rom[snk_data_i];
    // 2. decode and drive output
    if (reg_valid) begin
      src_data_o    <= reg_dec[9:2];
      src_control_o <= reg_dec[0];
      if (reg_dec[1])
        reg_rd <= ~reg_rd;
      // VHDL reduction and()
      src_valid_o <= ~(&reg_dec);
    end else begin
      src_valid_o <= 1'b0;
    end
  end

endmodule
