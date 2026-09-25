// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// VHDL package `types` in library `colibri` is SystemVerilog package `colibri_types`.
// Unconstrained records and arrays are fixed at the declaration. See CONVENTIONS.md.

`timescale 1ns/1ps

package colibri_types;

  import colibri_utils::*;

  typedef enum logic {
    BIG    = 1'b0,
    LITTLE = 1'b1
  } endian_t;

  // AXI4-Lite records. Field order is the VHDL record order, MSB first.
  typedef struct packed {
    logic [31:0] awaddr;
    logic [2:0]  awprot;
    logic        awvalid;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        bready;
  } axil_wr_master_t;

  localparam axil_wr_master_t c_AXIL_WR_MASTER_INIT = '{
    awaddr:  '0,
    awprot:  '0,
    awvalid: 1'b0,
    wdata:   '0,
    wstrb:   '1,
    wvalid:  1'b0,
    bready:  1'b0
  };

  typedef struct packed {
    logic       awready;
    logic       wready;
    logic [1:0] bresp;
    logic       bvalid;
  } axil_wr_slave_t;

  localparam axil_wr_slave_t c_AXIL_WR_SLAVE_INIT = '{
    awready: 1'b0,
    wready:  1'b0,
    bresp:   '0,
    bvalid:  1'b0
  };

  typedef struct packed {
    logic [31:0] araddr;
    logic [2:0]  arprot;
    logic        arvalid;
    logic        rready;
  } axil_rd_master_t;

  localparam axil_rd_master_t c_AXIL_RD_MASTER_INIT = '{
    araddr:  '0,
    arprot:  '0,
    arvalid: 1'b0,
    rready:  1'b0
  };

  typedef struct packed {
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
  } axil_rd_slave_t;

  localparam axil_rd_slave_t c_AXIL_RD_SLAVE_INIT = '{
    arready: 1'b0,
    rdata:   '0,
    rresp:   '0,
    rvalid:  1'b0
  };

  typedef struct packed {
    logic tready;
  } axis_slave_t;

  localparam axis_slave_t c_AXIS_SLAVE_INIT = '{tready: 1'b0};

  typedef struct packed {
    logic ready;
  } avst_slave_t;

  localparam avst_slave_t c_AVST_SLAVE_INIT = '{ready: 1'b0};

  function automatic int axis_keep_width(input int tdata_width);
    return div_ceil(tdata_width, 8);
  endfunction

  function automatic int avst_empty_width(input int data_width, input int symbol_width);
    int nsym;
    if (symbol_width <= 0)
      return 1;
    nsym = data_width / symbol_width;
    return maximum(log2ceil(nsym), 1);
  endfunction

  function automatic logic bool_to_sl(input bit arg);
    if (arg)
      return 1'b1;
    return 1'b0;
  endfunction

  // 2-state: only 0 and 1 exist, so anything other than 1'b1 is 0.
  function automatic int sl_to_int(input logic arg);
    if (arg == 1'b1)
      return 1;
    return 0;
  endfunction

  // Fixed-width AXI4-Stream master. tkeep width is div_ceil(DATA_W, 8).
  class axis #(parameter int DATA_W = 8);
    localparam int KEEP_W = (axis_keep_width(DATA_W) < 1) ? 1 : axis_keep_width(DATA_W);

    typedef struct packed {
      logic [DATA_W-1:0] tdata;
      logic [KEEP_W-1:0] tkeep;
      logic              tlast;
      logic              tvalid;
    } master_t;

    static function automatic master_t master_init();
      master_t v_axis;
      v_axis.tdata  = '0;
      v_axis.tkeep  = '0;
      v_axis.tlast  = 1'b0;
      v_axis.tvalid = 1'b0;
      return v_axis;
    endfunction
  endclass

  // Fixed-width Avalon-ST master. empty width matches avst_master_init.
  class avst #(parameter int DATA_W = 8, parameter int SYM_W = 8);
    localparam int EMPTY_W = avst_empty_width(DATA_W, SYM_W);

    typedef struct packed {
      logic [DATA_W-1:0]   data;
      logic [EMPTY_W-1:0]  empty;
      logic                sop;
      logic                eop;
      logic                valid;
    } master_t;

    static function automatic master_t master_init();
      master_t v_avst;
      v_avst.data  = '0;
      v_avst.empty = '0;
      v_avst.sop   = 1'b0;
      v_avst.eop   = 1'b0;
      v_avst.valid = 1'b0;
      return v_avst;
    endfunction
  endclass

  // slv_array_t indexed 0 .. N-1. Element 0 is packed into the MSBs.
  class slv_arr #(parameter int N = 1, parameter int W = 1);
    typedef logic [W-1:0] word_t;
    typedef word_t arr_t [0:N-1];

    static function automatic logic [N*W-1:0] to_slv(input word_t arg [0:N-1]);
      logic [N*W-1:0] v_slv;
      for (int i = 0; i < N; i++)
        v_slv[(N * W - 1) - (i * W) -: W] = arg[i];
      return v_slv;
    endfunction

    static function automatic arr_t from_slv(input logic [N*W-1:0] arg);
      arr_t v_arr;
      for (int i = 0; i < N; i++)
        v_arr[i] = arg[(N * W - 1) - (i * W) -: W];
      return v_arr;
    endfunction

    static function automatic arr_t shift_left_arr(input word_t arg [0:N-1], input int c_n);
      logic [N*W-1:0] v_slv;
      v_slv = to_slv(arg) << (c_n * W);
      return from_slv(v_slv);
    endfunction

    static function automatic arr_t shift_right_arr(input word_t arg [0:N-1], input int c_n);
      logic [N*W-1:0] v_slv;
      v_slv = to_slv(arg) >> (c_n * W);
      return from_slv(v_slv);
    endfunction
  endclass

  // uns_array_t. DST_W is c_elem_size. SRC_W is the element width before resize.
  class uns_arr #(parameter int N = 1, parameter int SRC_W = 1, parameter int DST_W = SRC_W);
    typedef logic [SRC_W-1:0] src_t;
    typedef logic [DST_W-1:0] dst_t;
    typedef src_t src_arr_t [0:N-1];
    typedef dst_t dst_arr_t [0:N-1];
    typedef int int_arr_t [0:N-1];

    static function automatic logic [N*DST_W-1:0] to_slv(input src_t arg [0:N-1]);
      logic [N*DST_W-1:0] v_slv;
      // VHDL `assert c_elem_size /= element_length` fires when the sizes match.
      if (DST_W == SRC_W)
        $warning("Warning: Mismatch between element size and array element size (it will be resized to c_ELEM_SIZE)");
      for (int i = 0; i < N; i++)
        v_slv[(N * DST_W - 1) - (i * DST_W) -: DST_W] = DST_W'(arg[i]);
      return v_slv;
    endfunction

    static function automatic dst_arr_t from_slv(input logic [N*DST_W-1:0] arg);
      dst_arr_t v_arr;
      for (int i = 0; i < N; i++)
        v_arr[i] = arg[(N * DST_W - 1) - (i * DST_W) -: DST_W];
      return v_arr;
    endfunction

    static function automatic int_arr_t to_int(input src_t arg [0:N-1]);
      int_arr_t v_arr;
      for (int i = 0; i < N; i++)
        v_arr[i] = int'(arg[i]);
      return v_arr;
    endfunction

    static function automatic dst_arr_t from_int(input int arg [0:N-1]);
      dst_arr_t v_arr;
      for (int i = 0; i < N; i++)
        v_arr[i] = DST_W'(arg[i]);
      return v_arr;
    endfunction

    static function automatic src_t sum_uns(input src_t arg [0:N-1]);
      src_t v_out;
      v_out = '0;
      for (int i = 0; i < N; i++)
        v_out = v_out + arg[i];
      return v_out;
    endfunction
  endclass

  class sig_arr #(parameter int N = 1, parameter int W = 1);
    typedef logic signed [W-1:0] word_t;
    typedef word_t arr_t [0:N-1];

    static function automatic word_t sum_sig(input word_t arg [0:N-1]);
      word_t v_out;
      v_out = '0;
      for (int i = 0; i < N; i++)
        v_out = v_out + arg[i];
      return v_out;
    endfunction
  endclass

  class int_arr #(parameter int N = 1);
    typedef int arr_t [0:N-1];

    static function automatic int sum_int(input int arg [0:N-1]);
      int v_out;
      v_out = 0;
      for (int i = 0; i < N; i++)
        v_out = v_out + arg[i];
      return v_out;
    endfunction
  endclass

endpackage

// Macro arguments must not themselves contain commas. Widths that need a
// function call go in a localparam first. See CONVENTIONS.md.

`define COLIBRI_SLV_ARRAY(name, left, right, elem_w) \
  logic [(elem_w)-1:0] name [(left):(right)]

`define COLIBRI_UNS_ARRAY(name, left, right, elem_w) \
  logic [(elem_w)-1:0] name [(left):(right)]

`define COLIBRI_SIG_ARRAY(name, left, right, elem_w) \
  logic signed [(elem_w)-1:0] name [(left):(right)]

`define COLIBRI_INT_ARRAY(name, left, right) \
  int name [(left):(right)]

`define COLIBRI_NAT_ARRAY(name, left, right) \
  int unsigned name [(left):(right)]

`define COLIBRI_POS_ARRAY(name, left, right) \
  int unsigned name [(left):(right)]

`define COLIBRI_SLV_ARRAY_2D(name, o_left, o_right, i_left, i_right, elem_w) \
  logic [(elem_w)-1:0] name [(o_left):(o_right)][(i_left):(i_right)]

`define COLIBRI_UNS_ARRAY_2D(name, o_left, o_right, i_left, i_right, elem_w) \
  logic [(elem_w)-1:0] name [(o_left):(o_right)][(i_left):(i_right)]

`define COLIBRI_SIG_ARRAY_2D(name, o_left, o_right, i_left, i_right, elem_w) \
  logic signed [(elem_w)-1:0] name [(o_left):(o_right)][(i_left):(i_right)]

`define COLIBRI_INT_ARRAY_2D(name, o_left, o_right, i_left, i_right) \
  int name [(o_left):(o_right)][(i_left):(i_right)]

`define COLIBRI_NAT_ARRAY_2D(name, o_left, o_right, i_left, i_right) \
  int unsigned name [(o_left):(o_right)][(i_left):(i_right)]

`define COLIBRI_POS_ARRAY_2D(name, o_left, o_right, i_left, i_right) \
  int unsigned name [(o_left):(o_right)][(i_left):(i_right)]

`define COLIBRI_AXIS_MASTER_T(td_name, data_w, keep_w) \
  typedef struct packed { \
    logic [(data_w)-1:0] tdata; \
    logic [(keep_w)-1:0] tkeep; \
    logic tlast; \
    logic tvalid; \
  } td_name

`define COLIBRI_AVST_MASTER_T(td_name, data_w, empty_w) \
  typedef struct packed { \
    logic [(data_w)-1:0] data; \
    logic [(empty_w)-1:0] empty; \
    logic sop; \
    logic eop; \
    logic valid; \
  } td_name

`define COLIBRI_AXIS_MASTER_INIT '{tdata: '0, tkeep: '0, tlast: 1'b0, tvalid: 1'b0}
`define COLIBRI_AVST_MASTER_INIT '{data: '0, empty: '0, sop: 1'b0, eop: 1'b0, valid: 1'b0}

`define COLIBRI_AXIL_WR_MASTER_ARRAY(name, left, right) \
  colibri_types::axil_wr_master_t name [(left):(right)]

`define COLIBRI_AXIL_WR_SLAVE_ARRAY(name, left, right) \
  colibri_types::axil_wr_slave_t name [(left):(right)]

`define COLIBRI_AXIL_RD_MASTER_ARRAY(name, left, right) \
  colibri_types::axil_rd_master_t name [(left):(right)]

`define COLIBRI_AXIL_RD_SLAVE_ARRAY(name, left, right) \
  colibri_types::axil_rd_slave_t name [(left):(right)]

`define COLIBRI_AXIS_SLAVE_ARRAY(name, left, right) \
  colibri_types::axis_slave_t name [(left):(right)]

`define COLIBRI_AVST_SLAVE_ARRAY(name, left, right) \
  colibri_types::avst_slave_t name [(left):(right)]
