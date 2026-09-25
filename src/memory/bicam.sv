// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Binary content-addressable memory.
// g_N_WORDS and g_DATA_WIDTH have elaboration defaults; the VHDL generics do not.

`timescale 1ns/1ps

module bicam #(
  parameter int g_N_WORDS    = 16,
  parameter int g_DATA_WIDTH = 8
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic rdreq_i,
  input  logic wrreq_i,
  input  logic clear_i,
  input  logic [g_DATA_WIDTH-1:0] data_i,
  output logic full_o,
  output logic busy_o,
  output logic match_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_o
);

  localparam int c_ADDR_W = colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS));

  typedef struct packed {
    logic [g_N_WORDS-1:0]    used_vec;
    logic [c_ADDR_W-1:0]     addr;
    logic [g_DATA_WIDTH-1:0] data;
    logic                    match;
    logic                    write;
  } sig_t;

  function automatic logic [c_ADDR_W-1:0] find_first(input logic [g_N_WORDS-1:0] vec);
    logic [c_ADDR_W-1:0] v_res;
    v_res = '0;
    for (int i = g_N_WORDS - 1; i >= 0; i--) begin
      if (vec[i] == 1'b0)
        v_res = c_ADDR_W'(i);
    end
    return v_res;
  endfunction

  logic [g_DATA_WIDTH-1:0] cam [0:g_N_WORDS-1];
  sig_t rreg;
  sig_t rcmb;
  localparam sig_t c_SIG_INIT = '0;

  initial rreg = c_SIG_INIT;

  always_ff @(posedge clk_i) begin : proc_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_fsm
    sig_t v_int;
    v_int       = rreg;
    v_int.match = 1'b0;
    v_int.addr  = '0;
    v_int.write = 1'b0;

    if (reset_i) begin
      v_int.used_vec = '0;
      v_int.data     = '0;
    end else if (rreg.write) begin
      v_int.write = 1'b0;
      v_int.addr  = '0;
      v_int.used_vec[int'(rreg.addr)] = 1'b1;
    end else if (wrreq_i && clear_i) begin
      for (int i = 0; i < g_N_WORDS; i++) begin
        if ((rreg.used_vec[i] == 1'b1) && (cam[i] == data_i)) begin
          v_int.match = 1'b1;
          v_int.used_vec[i] = 1'b0;
          v_int.addr = c_ADDR_W'(i);
        end
      end
    end else if (wrreq_i && !full_o) begin
      if (rreg.used_vec == '0)
        v_int.addr = '0;
      else
        v_int.addr = find_first(rreg.used_vec);
      v_int.data  = data_i;
      v_int.write = 1'b1;
    end else if (rdreq_i) begin
      for (int i = 0; i < g_N_WORDS; i++) begin
        if ((rreg.used_vec[i] == 1'b1) && (cam[i] == data_i)) begin
          v_int.match = 1'b1;
          v_int.addr  = c_ADDR_W'(i);
        end
      end
    end

    rcmb = v_int;
  end

  assign full_o  = &rreg.used_vec;
  assign addr_o  = rreg.addr;
  assign busy_o  = rreg.write;
  assign match_o = rreg.match;

  always_ff @(posedge clk_i) begin : proc_write_to_cam
    if (rreg.write)
      cam[int'(rreg.addr)] <= rreg.data;
  end

endmodule
