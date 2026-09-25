// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Power-up reset generator.
// Generates a fixed duration reset pulse at start-up. Polarity and duration
// come from `g_POLARITY` and `g_DURATION`. `reset_ext_i` is asynchronous and
// active high. `reset_o` is synchronous to `clk_i`.

`timescale 1ns/1ps

// verilator lint_off MULTITOP
module powerup_reset #(
  parameter logic g_POLARITY = 1'b1,
  parameter int unsigned g_DURATION = 16
) (
  input  logic clk_i,
  input  logic reset_ext_i,
  output logic reset_o
);

  typedef struct {
    int unsigned counter;
    logic        reset;
  } reg_t;

  function automatic reg_t reg_init();
    reg_t v;
    v.counter = 0;
    v.reset   = g_POLARITY;
    return v;
  endfunction

  reg_t r;
  reg_t rin;

  initial r = reg_init();

  always_comb begin : proc_comb
    reg_t v_reg;
    v_reg = r;
    if (r.reset == g_POLARITY)
      v_reg.counter = r.counter + 1;
    if (r.counter >= g_DURATION - 1)
      v_reg.reset = ~g_POLARITY;
    rin     = v_reg;
    reset_o = r.reset;
  end

  always_ff @(posedge clk_i or posedge reset_ext_i) begin : proc_seq
    if (reset_ext_i)
      r <= reg_init();
    else
      r <= rin;
  end

endmodule
