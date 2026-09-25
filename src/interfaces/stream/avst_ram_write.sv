// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Simple Avalon Stream to RAM writer.
// Sequential writes of a packeted Avalon-ST input. start_addr_i is sampled at
// start of packet. A later start of packet restarts from the new address.
// The write stops on end of packet.

`timescale 1ns/1ps

module avst_ram_write #(
  parameter int unsigned g_DATA_WIDTH = 8,
  parameter int unsigned g_ADDR_WIDTH = 8
) (
  input  logic                      clk_i,
  input  logic                      reset_i,
  input  logic [g_ADDR_WIDTH-1:0]   start_addr_i,
  input  logic                      snk_sop_i,
  input  logic                      snk_eop_i,
  input  logic [g_DATA_WIDTH-1:0]   snk_data_i,
  input  logic                      snk_valid_i,
  output logic                      wr_en_o,
  output logic [g_ADDR_WIDTH-1:0]   wr_addr_o,
  output logic [g_DATA_WIDTH-1:0]   wr_data_o
);

  typedef struct packed {
    logic                      en;
    logic [g_ADDR_WIDTH-1:0]   addr;
    logic [g_DATA_WIDTH-1:0]   data;
  } ram_wr_t;

  typedef struct packed {
    logic                    active;
    logic [g_ADDR_WIDTH-1:0] addr;
    ram_wr_t                 ram_wr;
  } reg_t;

  localparam ram_wr_t c_RAM_WR_INIT = '{en: 1'b0, addr: '0, data: '0};
  localparam reg_t c_REG_TYPE_INIT = '{
    active: 1'b0,
    addr:   '0,
    ram_wr: c_RAM_WR_INIT
  };

  reg_t r   = c_REG_TYPE_INIT;
  reg_t rin;

  // Two-process structure.
  always_comb begin : proc_comb
    reg_t v;
    v = r;

    if (snk_sop_i && snk_valid_i) begin
      v.active = 1'b1;
      v.addr   = start_addr_i;
    end

    if (v.active && snk_valid_i) begin
      v.ram_wr = '{
        en:   1'b1,
        addr: v.addr,
        data: snk_data_i
      };
      v.addr = v.addr + g_ADDR_WIDTH'(1);
    end else begin
      v.ram_wr = c_RAM_WR_INIT;
    end

    if (snk_eop_i && snk_valid_i)
      v.active = 1'b0;

    if (reset_i)
      v = c_REG_TYPE_INIT;

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_seq
    r <= rin;
  end

  assign wr_en_o   = r.ram_wr.en;
  assign wr_addr_o = r.ram_wr.addr;
  assign wr_data_o = r.ram_wr.data;

endmodule
