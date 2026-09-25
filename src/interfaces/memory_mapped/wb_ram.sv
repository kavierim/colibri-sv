// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Wishbone RAM interface.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

module wb_ram #(
  // VHDL leaves g_N_WORDS without a default. Verilator elaborates this module
  // on its own, so a default is required. Instantiations still pass g_N_WORDS.
  parameter int unsigned g_N_WORDS       = 16,
  parameter int unsigned g_WB_DATA_WIDTH = 32,
  parameter int unsigned g_WB_ADDR_WIDTH = 32,
  localparam int c_ADDR_RAW = colibri_utils::log2ceil(int'(g_N_WORDS)),
  localparam int c_ADDR_W   = colibri_utils::downto_width(c_ADDR_RAW),
  localparam int c_SEL_W    = colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)
) (
  input  logic                         clk_i,
  input  logic                         reset_i,
  input  logic [g_WB_ADDR_WIDTH-1:0]   wb_adr_i,
  input  logic [g_WB_DATA_WIDTH-1:0]   wb_dat_i,
  output logic [g_WB_DATA_WIDTH-1:0]   wb_dat_o,
  input  logic                         wb_we_i,
  input  logic [c_SEL_W-1:0]           wb_sel_i,
  input  logic                         wb_stb_i,
  input  logic                         wb_cyc_i,
  output logic                         wb_ack_o,
  output logic                         wb_err_o
);

  localparam int c_BYTES = int'(g_WB_DATA_WIDTH) / 8;

  logic [g_WB_ADDR_WIDTH-1:0] word_addr;
  logic [c_ADDR_W-1:0]        addr;
  logic                       we;
  logic [g_WB_DATA_WIDTH-1:0] data;
  logic [g_WB_DATA_WIDTH-1:0] q;
  logic                       valid_addr;
  logic [c_ADDR_W-1:0]        word_addr_low;

  // wb_sel_i is an entity port. The VHDL architecture does not read it.
  // verilator lint_off UNUSEDSIGNAL
  logic unused_wb_sel;
  assign unused_wb_sel = |wb_sel_i;
  // verilator lint_on UNUSEDSIGNAL

  assign word_addr = wb_adr_i / g_WB_ADDR_WIDTH'(c_BYTES);

  // VHDL `or` of a null slice is '0'. A one-word RAM has a null address, so
  // addr'length is 0 and the slice is the entire word address.
  if (c_ADDR_RAW == 0) begin : gen_valid_one_word
    assign valid_addr = ~(|word_addr);
  end else if (c_ADDR_RAW >= int'(g_WB_ADDR_WIDTH)) begin : gen_valid_full
    assign valid_addr = 1'b1;
  end else begin : gen_valid_high
    assign valid_addr = ~(|word_addr[g_WB_ADDR_WIDTH-1:c_ADDR_RAW]);
  end

  if (c_ADDR_W <= int'(g_WB_ADDR_WIDTH)) begin : gen_addr_fit
    assign word_addr_low = word_addr[c_ADDR_W-1:0];
  end else begin : gen_addr_wide
    assign word_addr_low = c_ADDR_W'(word_addr);
  end

  assign we       = wb_we_i && wb_stb_i && wb_cyc_i && valid_addr;
  assign addr     = valid_addr ? word_addr_low : '0;
  assign wb_dat_o = (wb_cyc_i && wb_ack_o) ? q : '0;
  assign data     = (wb_stb_i && wb_cyc_i && valid_addr) ? wb_dat_i : '0;

  always_ff @(posedge clk_i) begin : proc_wb_iface
    if (reset_i == 1'b1) begin
      wb_ack_o <= 1'b0;
      wb_err_o <= 1'b0;
    end else begin
      wb_ack_o <= 1'b0;
      wb_err_o <= 1'b0;
      if (wb_stb_i && wb_cyc_i) begin
        if (valid_addr)
          wb_ack_o <= 1'b1;
        else
          wb_err_o <= 1'b1;
      end
    end
  end

  ram #(
    .g_N_WORDS      (g_N_WORDS),
    .g_DATA_WIDTH   (g_WB_DATA_WIDTH),
    .g_REGISTER_IN  (1'b0),
    .g_REGISTER_OUT (1'b1)
  ) ram_inst (
    .clk_i   (clk_i),
    .reset_i (reset_i),
    .addr_i  (addr),
    .we_i    (we),
    .data_i  (data),
    .q_o     (q)
  );

endmodule
