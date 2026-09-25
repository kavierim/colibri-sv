// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Lint anchor so Wave 0 packages and counter are elaborated. Not library RTL.
// Later agents leave this file in the list.

`timescale 1ns/1ps

module wave0_elab (
  output logic sink_o
);
  import colibri_utils::*;
  import colibri_types::*;
  import colibri_encoders::*;
  import colibri_poly::*;
  import colibri_mem::*;

  logic clk_i;
  logic reset_i;
  logic enable_i;
  logic wraparound_o;
  logic [2:0] value_o;
  logic [7:0] reversed;
  logic [3:0] gray;
  logic [7:0] summed;
  logic reg_q;
  logic comb_q;
  localparam int c_KEEP_W = axis_keep_width(16);
  localparam int c_EMPTY_W = avst_empty_width(32, 8);

  if (log2ceil(0) != 0 || log2ceil(1) != 0 || log2ceil(2) != 1 || log2ceil(3) != 2
      || log2ceil(4) != 2 || log2ceil(8) != 3 || div_ceil(0, 4) != 0
      || div_ceil(1, 4) != 1 || div_ceil(4, 4) != 1 || div_ceil(5, 4) != 2
      || minimum(3, 7) != 3 || maximum(3, 7) != 7 || maximum(4, 4) != 4
      || greatest_common_div(12, 18) != 6 || least_common_mult(4, 6) != 12
      || div_ceil_time(10ms, 1ns) != 10000000 || if_sel(1'b1, 3, 4) != 3
      || if_sel(1'b0, 3, 4) != 4 || downto_width(0) != 1 || downto_width(5) != 5
      || c_KEEP_W != 2 || c_EMPTY_W != 2 || get_compiler() != AUTO)
    begin : gen_bad_math
      $error("colibri_utils constant function mismatch");
    end

  if ($bits(c_CRC_1) != 1 || c_CRC_1 != 1'b1 || $bits(c_CRC_3_GSM) != 3 || c_CRC_3_GSM != 3'h3
      || $bits(c_CRC_5_USB) != 5 || c_CRC_5_USB != 5'h05 || c_CRC_8 != 8'h07
      || c_CRC_16_CCITT != 16'h1021 || c_CRC_32 != 32'h04c11db7
      || $bits(c_SCR_10GBASE) != 58 || c_SCR_10GBASE != 58'h80001
      || c_PRBS_5 != 6'h29 || c_PRBS_7 != 8'hc1 || c_PRBS_15 != 16'hc001
      || c_PRBS_23 != 24'h840001 || c_PRBS_31 != 32'h90000001)
    begin : gen_bad_poly
      $error("colibri_poly constant mismatch");
    end

  `COLIBRI_AXIS_MASTER_T(axis_t, 16, c_KEEP_W);
  `COLIBRI_AVST_MASTER_T(avst_t, 32, c_EMPTY_W);
  axis_t axis_bus;
  avst_t avst_bus;
  axis#(16)::master_t axis_cls;
  avst#(32, 8)::master_t avst_cls;
  logic [7:0] ram [0:3];
  logic [3:0] grid_word [0:1][0:1];
  logic [7:0] sliced;
  logic [7:0] even_bits;
  logic [15:0] swapped;
  logic [15:0] packed_lanes;
  logic [3:0] bin_back;
  logic [3:0] oh_full;
  logic [1:0] oh_idx;
  logic [3:0] oh_lim;
  logic [1:0] pri_idx;
  logic [3:0] bcd;
  logic xbit;

  assign clk_i    = 1'b0;
  assign reset_i  = 1'b0;
  assign enable_i = 1'b0;

  counter #(
    .g_MODULO(8)
  ) u_counter (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .enable_i(enable_i),
    .value_o(value_o),
    .wraparound_o(wraparound_o)
  );

  `COLIBRI_SLV_ARRAY(lanes, 0, 1, 8);

  assign reversed   = bits#(8)::invert_bit_order(8'hA5);
  assign gray       = enc#(4)::bin2gray(4'h6);
  assign summed     = uval#(8)::div_ceil(8'd10, 3);
  assign sliced     = byteslice#(8)::slice_bytes_left(8'hF0, 1);
  assign even_bits  = bits#(8)::gen_even();
  assign swapped    = bits#(16)::swap_endianness(16'h0123);
  assign bin_back   = enc#(4)::gray2bin(gray);
  assign oh_full    = onehot_enc#(2)::bin2onehot(2'b01);
  assign oh_idx     = onehot_dec#(4)::onehot2bin(4'b0100);
  assign oh_lim     = onehot_lim#(4)::bin2onehot(2'd2);
  assign pri_idx    = pri#(4)::priority_encode(4'b0100);
  assign bcd        = bin2bcd(7);
  assign xbit       = bits#(8)::xorvec(reversed) ^ bits#(8)::andvec(reversed);
  assign packed_lanes = slv_arr#(2, 8)::to_slv(lanes);

  `COLIBRI_WHEN_REGISTERED(elab_reg, clk_i, 1'b1, reg_q, enable_i)
  `COLIBRI_WHEN_REGISTERED(elab_comb, clk_i, 1'b0, comb_q, enable_i)

  assign lanes[0] = reversed;
  assign lanes[1] = {gray, gray};

  initial begin
    axis_bus = `COLIBRI_AXIS_MASTER_INIT;
    avst_bus = `COLIBRI_AVST_MASTER_INIT;
    axis_cls = axis#(16)::master_init();
    avst_cls = avst#(32, 8)::master_init();
    ram = flat#(8, 4)::init_mem_hex("", 8'h3C);
    grid_word = grid#(4, 2, 2)::init_mem_hex("", 4'hA);
  end

  assign sink_o = (^value_o) ^ wraparound_o ^ (^reversed) ^ (^gray) ^ (^summed)
    ^ reg_q ^ comb_q ^ (^lanes[0]) ^ (^lanes[1]) ^ (^sliced) ^ (^even_bits)
    ^ (^swapped) ^ (^packed_lanes) ^ (^bin_back) ^ (^oh_full) ^ (^oh_idx)
    ^ (^oh_lim) ^ (^pri_idx) ^ (^bcd) ^ xbit
    ^ (^axis_bus) ^ (^avst_bus) ^ (^axis_cls) ^ (^avst_cls)
    ^ (^ram[0]) ^ (^ram[1]) ^ (^ram[2]) ^ (^ram[3])
    ^ (^grid_word[0][0]) ^ (^grid_word[0][1]) ^ (^grid_word[1][0]) ^ (^grid_word[1][1])
    ^ (^c_AXIL_WR_MASTER_INIT) ^ (^c_AXIL_WR_SLAVE_INIT) ^ (^c_AXIL_RD_MASTER_INIT)
    ^ (^c_AXIL_RD_SLAVE_INIT) ^ c_AXIS_SLAVE_INIT.tready ^ c_AVST_SLAVE_INIT.ready
    ^ bool_to_sl(1'b1) ^ logic'(sl_to_int(1'b1));
endmodule
