// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit avst_ram_write_unaligned_vu, bound into avst_ram_write_unaligned.
module avst_ram_write_unaligned_sva #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 16,
  localparam int c_DATA_W      = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W     = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_BYTE_ADDR_W = colibri_utils::downto_width(
    colibri_utils::log2ceil(int'(g_RAM_DEPTH) * int'(g_WORD_BYTES))),
  localparam int c_ADDR_W      = colibri_utils::downto_width(
    colibri_utils::log2ceil(int'(g_RAM_DEPTH)))
) (
  input logic                      clk_i,
  input logic                      reset_i,
  input logic [c_DATA_W-1:0]       snk_data_i,
  input logic [c_EMPTY_W-1:0]      snk_empty_i,
  input logic                      snk_sop_i,
  input logic                      snk_eop_i,
  input logic                      snk_valid_i,
  input logic                      snk_ready_o,
  input logic [c_BYTE_ADDR_W-1:0]  start_addr_i,
  input logic                      flush_i,
  input logic [g_WORD_BYTES-1:0]   wr_be_o,
  input logic [c_ADDR_W-1:0]       wr_addr_o,
  input logic [c_DATA_W-1:0]       wr_data_o,
  input logic [1:0]                state
);

  localparam logic [1:0] S_IDLE  = 2'd0;
  localparam logic [1:0] S_SOP   = 2'd1;
  localparam logic [1:0] S_WRITE = 2'd2;
  localparam logic [1:0] S_EOP   = 2'd3;

  logic first_cycle = 1'b1;

  // wr_addr_o / wr_data_o / snk_data_i are part of the bound port set.
  // verilator lint_off UNUSEDSIGNAL
  wire unused_ports = ^{wr_addr_o, wr_data_o, snk_data_i};
  // verilator lint_on UNUSEDSIGNAL

  function automatic int addr_mod();
    return int'(start_addr_i) % int'(g_WORD_BYTES);
  endfunction

  always_ff @(posedge clk_i) begin : proc_first
    first_cycle <= 1'b0;
  end

  assume property (@(posedge clk_i) first_cycle |-> reset_i);
  assume property (@(posedge clk_i) snk_valid_i |-> !flush_i);
  assume property (@(posedge clk_i) !snk_eop_i |-> (snk_empty_i == '0));

  assert property (@(posedge clk_i) reset_i |=> !(|wr_be_o) && (state == S_IDLE));

  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_IDLE) && !(snk_valid_i && snk_sop_i && snk_ready_o) |=> (state == S_IDLE));
  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_IDLE) && snk_valid_i && snk_sop_i && snk_ready_o |=> (state == S_SOP));

  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_SOP) && !(
      (snk_sop_i && snk_valid_i && snk_ready_o) &&
      $past(snk_eop_i && (int'(snk_empty_i) >= addr_mod()))
    ) |=> (state != S_SOP));

  // (A ##1 B) |=> C is $past(A) && B |=> C. Cycle delays are not accepted here.
  assert property (@(posedge clk_i) disable iff (reset_i)
    $past(snk_eop_i && (int'(snk_empty_i) >= addr_mod())) &&
    (state == S_SOP) && snk_sop_i && snk_valid_i && snk_ready_o |=> (state == S_SOP));

  assert property (@(posedge clk_i) disable iff (reset_i)
    $past(snk_eop_i && (int'(snk_empty_i) >= addr_mod())) &&
    (state == S_SOP) && !snk_sop_i |=> (state == S_IDLE));

  assert property (@(posedge clk_i) disable iff (reset_i)
    $past(!snk_eop_i) && (state == S_SOP) && !snk_eop_i && !flush_i |=> (state == S_WRITE));

  assert property (@(posedge clk_i) disable iff (reset_i)
    $past(snk_eop_i && (int'(snk_empty_i) < addr_mod())) && (state == S_SOP) |=>
      (state == S_EOP));

  assert property (@(posedge clk_i) disable iff (reset_i)
    $past(!snk_eop_i) && snk_eop_i && snk_valid_i && (state == S_SOP) |=> (state == S_EOP));

  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_WRITE) && (!snk_eop_i || !snk_valid_i) && !flush_i |=> (state == S_WRITE));
  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_WRITE) && ((snk_eop_i && snk_valid_i) || flush_i) |=> (state == S_EOP));

  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_EOP) && !snk_ready_o |=> (state == S_EOP));
  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_EOP) && snk_ready_o && (!snk_sop_i || !snk_valid_i) |=> (state == S_IDLE));
  assert property (@(posedge clk_i) disable iff (reset_i)
    (state == S_EOP) && snk_ready_o && snk_sop_i && snk_valid_i |=> (state == S_SOP));

  assert property (@(posedge clk_i) disable iff (reset_i)
    (state != S_IDLE) && (state != S_EOP) && flush_i |=>
      (state == S_IDLE) || (state == S_EOP));

endmodule

bind avst_ram_write_unaligned avst_ram_write_unaligned_sva #(
  .g_BYTE_WIDTH (g_BYTE_WIDTH),
  .g_WORD_BYTES (g_WORD_BYTES),
  .g_RAM_DEPTH  (g_RAM_DEPTH)
) avst_ram_write_unaligned_sva_i (
  .clk_i        (clk_i),
  .reset_i      (reset_i),
  .snk_data_i   (snk_data_i),
  .snk_empty_i  (snk_empty_i),
  .snk_sop_i    (snk_sop_i),
  .snk_eop_i    (snk_eop_i),
  .snk_valid_i  (snk_valid_i),
  .snk_ready_o  (snk_ready_o),
  .start_addr_i (start_addr_i),
  .flush_i      (flush_i),
  .wr_be_o      (wr_be_o),
  .wr_addr_o    (wr_addr_o),
  .wr_data_o    (wr_data_o),
  .state        (r.state)
);
