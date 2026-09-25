// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Big-endian add-trailing-word module.
// Adds `snk_trail_i` at the end of an Avalon-ST packet.
// `snk_trail_i` and `shl_i` are sampled at `snk_eop_i`.

`timescale 1ns/1ps

module be_add_trail #(
  parameter int unsigned g_DATA_WIDTH = 32
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8):0] shl_i,
  output logic snk_ready_o,
  input  logic snk_valid_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))-1:0] snk_empty_i,
  input  logic [g_DATA_WIDTH-1:0] snk_data_i,
  input  logic [g_DATA_WIDTH-1:0] snk_trail_i,
  input  logic src_ready_i,
  output logic src_valid_o,
  output logic src_sop_o,
  output logic src_eop_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8))-1:0] src_empty_o,
  output logic [g_DATA_WIDTH-1:0] src_data_o
);

  localparam int c_DATA_BYTES = int'(g_DATA_WIDTH) / 8;
  localparam int c_EMPTY_W = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH) / 8));

  `COLIBRI_AVST_MASTER_T(avst_t, g_DATA_WIDTH, c_EMPTY_W);

  function automatic logic [g_DATA_WIDTH-1:0] shl_bytes(
    input logic [g_DATA_WIDTH-1:0] vec,
    input int n
  );
    if (n <= 0)
      return vec;
    if (n >= c_DATA_BYTES)
      return '0;
    return vec << (n * 8);
  endfunction

  // {hi_src[W-1:n*8], lo_src[W-1 -: n*8]}, null slice when n is 0 or full width.
  function automatic logic [g_DATA_WIDTH-1:0] join_hi_with_top(
    input logic [g_DATA_WIDTH-1:0] hi_src,
    input logic [g_DATA_WIDTH-1:0] lo_src,
    input int n
  );
    logic [g_DATA_WIDTH-1:0] low_mask;
    if (n <= 0)
      return hi_src;
    if (n >= c_DATA_BYTES)
      return lo_src;
    low_mask = ~({g_DATA_WIDTH{1'b1}} << (n * 8));
    return ((hi_src >> (n * 8)) << (n * 8)) | ((lo_src >> (g_DATA_WIDTH - n * 8)) & low_mask);
  endfunction

  function automatic avst_t avst_init();
    return avst_t'(colibri_types::avst#(g_DATA_WIDTH)::master_init());
  endfunction

  typedef enum logic {
    S_DATA     = 1'b0,
    S_LATE_EOP = 1'b1
  } fsm_t;

  typedef struct {
    fsm_t                    state;
    logic [g_DATA_WIDTH-1:0] word_buf;
    int                      shl;
    logic                    ready;
    avst_t                   avst;
  } sig_t;

  function automatic sig_t sig_init();
    sig_t v;
    v.state    = S_DATA;
    v.word_buf = '0;
    v.shl      = 0;
    v.ready    = 1'b0;
    v.avst     = avst_init();
    return v;
  endfunction

  sig_t rreg;
  sig_t rcmb;
  logic fsm_ready;

  logic [g_DATA_WIDTH-1:0] skid_data;
  logic [c_EMPTY_W-1:0]    skid_empty;
  logic                    skid_sop;
  logic                    skid_eop;
  logic                    skid_valid;
  avst_t                   skid;

  logic [g_DATA_WIDTH-1:0] skid_trail;
  logic [g_DATA_WIDTH-1:0] skidb_trail;

  initial rreg = sig_init();

  assign skid = '{
    data:  skid_data,
    empty: skid_empty,
    sop:   skid_sop,
    eop:   skid_eop,
    valid: skid_valid
  };

  assign fsm_ready = rcmb.ready;

  // verilator lint_off PINCONNECTEMPTY
  skid_buffer #(
    .g_DATA_WIDTH(int'(g_DATA_WIDTH))
  ) skid_buffer_inst (
    .clk_i      (clk_i),
    .reset_i    (reset_i),
    .snk_data_i (snk_data_i),
    .snk_empty_i(snk_empty_i),
    .snk_keep_i ('0),
    .snk_sop_i  (snk_sop_i),
    .snk_eop_i  (snk_eop_i),
    .snk_valid_i(snk_valid_i),
    .snk_ready_o(snk_ready_o),
    .src_data_o (skid_data),
    .src_empty_o(skid_empty),
    .src_keep_o (),
    .src_sop_o  (skid_sop),
    .src_eop_o  (skid_eop),
    .src_valid_o(skid_valid),
    .src_ready_i(fsm_ready)
  );
  // verilator lint_on PINCONNECTEMPTY

  assign skid_trail = snk_ready_o ? snk_trail_i : skidb_trail;

  always_ff @(posedge clk_i) begin : proc_skid_trail
    if (snk_ready_o && snk_valid_i && !fsm_ready)
      skidb_trail <= snk_trail_i;
  end

  always_comb begin : proc_fsm
    sig_t v_int;
    v_int = rreg;
    if (rreg.avst.valid && src_ready_i)
      v_int.avst = avst_init();
    v_int.ready = ~v_int.avst.valid;

    case (rreg.state)
      S_DATA: begin
        if (skid.valid && v_int.ready) begin
          v_int.avst.sop = skid.sop;
          if (skid.sop)
            v_int.shl = int'(shl_i);
          v_int.avst.eop   = skid.eop;
          v_int.avst.valid = skid.valid;
          v_int.avst.empty = skid.empty;
          // VHDL loop is 0 to g_DATA_WIDTH/8-1.
          if (int'(skid.empty) < c_DATA_BYTES) begin
            v_int.avst.data = join_hi_with_top(skid.data, skid_trail, int'(skid.empty));
            v_int.word_buf  = shl_bytes(skid_trail, int'(skid.empty));
          end
          if (skid.eop) begin
            if (v_int.shl > int'(skid.empty)) begin
              v_int.avst.empty = c_EMPTY_W'(c_DATA_BYTES - (v_int.shl - int'(skid.empty)));
              v_int.avst.eop   = 1'b0;
              v_int.state      = S_LATE_EOP;
            end else begin
              v_int.avst.empty = c_EMPTY_W'(int'(skid.empty) - v_int.shl);
            end
          end
        end
      end
      S_LATE_EOP: begin
        if (v_int.ready) begin
          v_int.avst.sop   = 1'b0;
          v_int.avst.eop   = 1'b1;
          v_int.avst.valid = 1'b1;
          v_int.avst.empty = rreg.avst.empty;
          v_int.avst.data  = rreg.word_buf;
          v_int.state      = S_DATA;
        end
        v_int.ready = 1'b0;
      end
      default: v_int.state = S_DATA;
    endcase

    if (reset_i)
      v_int = sig_init();
    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_reg
    rreg <= rcmb;
  end

  assign src_sop_o   = rreg.avst.sop;
  assign src_eop_o   = rreg.avst.eop;
  assign src_valid_o = rreg.avst.valid;
  assign src_empty_o = rreg.avst.empty;
  assign src_data_o  = rreg.avst.data;

endmodule
