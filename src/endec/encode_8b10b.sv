// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// 8b/10b Encoder
// lookup table (ROM)-based 8b/10b encoder.
// The lookup table approach guarantees minimal resource usage and short combinatorial paths.
//
// Changelog:
// - 0.2 reformatted for Vivado to infer primitives

`timescale 1ns/1ps

// Library entity. Lint alongside verilator/wave0_elab.sv reports multiple tops.
// verilator lint_off MULTITOP
module encode_8b10b (
  input  logic       clk_i,
  input  logic [7:0] snk_data_i,
  input  logic       snk_valid_i,
  input  logic       snk_control_i, // inject K code
  output logic [9:0] src_data_o,
  output logic       src_valid_o
);

  logic [10:0] reg_enc;
  logic        reg_valid = 1'b0;
  logic        reg_rd    = 1'b0;
  // encoding ROM: declaration required for vivado to infer ROM primitives
  logic [10:0] encoding_rom [0:1023] = colibri_common_8b10b::c_ENCODE_ROM_8B10B;

  // two stage architecture
  always_ff @(posedge clk_i) begin : proc_main
    logic [9:0] v_addr;
    reg_valid <= snk_valid_i;
    // 1. read from rom and register
    if (snk_valid_i) begin
      v_addr  = {reg_rd, snk_control_i, snk_data_i};
      reg_enc <= encoding_rom[v_addr];
    end
    // 2. decode and drive output
    if (reg_valid) begin
      src_data_o <= reg_enc[10:1];
      if (reg_enc[0])
        reg_rd <= ~reg_rd;
      // VHDL reduction and()
      src_valid_o <= ~(&reg_enc);
    end else begin
      src_valid_o <= 1'b0;
    end
  end

endmodule
