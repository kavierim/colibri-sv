// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// PSL vunit avst_ram_write_vu, bound into avst_ram_write.
// anyconst equalities are written as direct data/address checks: the PSL
// property has to hold for every frozen value.
module avst_ram_write_sva #(
  parameter int unsigned g_DATA_WIDTH = 8,
  parameter int unsigned g_ADDR_WIDTH = 8
) (
  input logic                     clk_i,
  input logic                     reset_i,
  input logic [g_ADDR_WIDTH-1:0]  start_addr_i,
  input logic                     snk_sop_i,
  input logic                     snk_eop_i,
  input logic [g_DATA_WIDTH-1:0]  snk_data_i,
  input logic                     snk_valid_i,
  input logic                     wr_en_o,
  input logic [g_ADDR_WIDTH-1:0]  wr_addr_o,
  input logic [g_DATA_WIDTH-1:0]  wr_data_o
);

  logic packet_active = 1'b0;
  logic first_cycle = 1'b1;
  logic abort_addr;

  assign abort_addr = reset_i || ((snk_eop_i || snk_sop_i) && snk_valid_i);

  always_ff @(posedge clk_i) begin : proc_first
    first_cycle <= 1'b0;
  end

  always_ff @(posedge clk_i) begin : proc_packet
    if (snk_eop_i && snk_valid_i)
      packet_active <= 1'b0;
    else if (snk_sop_i && snk_valid_i)
      packet_active <= 1'b1;
    if (reset_i)
      packet_active <= 1'b0;
  end

  assume property (@(posedge clk_i) first_cycle |-> reset_i);

  assert property (@(posedge clk_i)
    reset_i |=> !wr_en_o && (wr_addr_o == '0) && (wr_data_o == '0));

  assert property (@(posedge clk_i) disable iff (reset_i)
    snk_sop_i && snk_valid_i |=>
      wr_en_o && (wr_data_o == $past(snk_data_i)) && (wr_addr_o == $past(start_addr_i)));

  assert property (@(posedge clk_i) disable iff (reset_i)
    packet_active && snk_valid_i |=> wr_en_o && (wr_data_o == $past(snk_data_i)));

  // Next write in the same packet uses the following address. Verilator 5.020
  // does not accept local variables or ## delays inside a property.
  logic                    addr_seen = 1'b0;
  logic [g_ADDR_WIDTH-1:0] addr_cap = '0;

  always_ff @(posedge clk_i) begin : proc_addr_inc
    if (abort_addr) begin
      addr_seen <= 1'b0;
    end else if (packet_active && wr_en_o) begin
      if (addr_seen)
        assert (wr_addr_o == (addr_cap + g_ADDR_WIDTH'(1)));
      addr_cap  <= wr_addr_o;
      addr_seen <= 1'b1;
    end
  end

  assert property (@(posedge clk_i) disable iff (reset_i)
    ((packet_active == 1'b0) && (snk_sop_i == 1'b0)) || (snk_valid_i == 1'b0) |=>
      (wr_en_o == 1'b0));

endmodule

bind avst_ram_write avst_ram_write_sva #(
  .g_DATA_WIDTH (g_DATA_WIDTH),
  .g_ADDR_WIDTH (g_ADDR_WIDTH)
) avst_ram_write_sva_i (
  .clk_i        (clk_i),
  .reset_i      (reset_i),
  .start_addr_i (start_addr_i),
  .snk_sop_i    (snk_sop_i),
  .snk_eop_i    (snk_eop_i),
  .snk_data_i   (snk_data_i),
  .snk_valid_i  (snk_valid_i),
  .wr_en_o      (wr_en_o),
  .wr_addr_o    (wr_addr_o),
  .wr_data_o    (wr_data_o)
);
