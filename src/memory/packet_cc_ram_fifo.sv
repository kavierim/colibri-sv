// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Packet FIFO in a simple dual-port RAM, with a latency fifo and a size cc_fifo.
// g_MAX_PACKET_BYTES and g_NUM_PACKETS have elaboration defaults; the VHDL generics do not.
// Sink shaping uses skid_buffer and stream_buffer (src/common).
// Resets use synchro_reset (src/common).
// The read-side state names are SRC_IDLE and SRC_PACKET. SystemVerilog enum
// labels share the module scope, so they cannot repeat the write-side S_IDLE
// and S_PACKET.

`timescale 1ns/1ps

module packet_cc_ram_fifo #(
  parameter int g_DATA_WIDTH       = 32,
  parameter int g_MAX_PACKET_BYTES = 256,
  parameter int g_NUM_PACKETS      = 4,
  parameter int g_SNK_DATA_WIDTH   = g_DATA_WIDTH,
  parameter int g_SRC_DATA_WIDTH   = g_DATA_WIDTH,
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic reset_i,
  input  logic snk_clk_i,
  input  logic src_clk_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic [g_SNK_DATA_WIDTH-1:0] snk_data_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_SNK_DATA_WIDTH / 8))-1:0] snk_empty_i,
  input  logic snk_valid_i,
  output logic snk_ready_o,
  input  logic snk_drop_i,
  output logic src_sop_o,
  output logic src_eop_o,
  output logic [g_SRC_DATA_WIDTH-1:0] src_data_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_SRC_DATA_WIDTH / 8))-1:0] src_empty_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_MAX_PACKET_BYTES * g_NUM_PACKETS))-1:0] src_size_o,
  input  logic src_ready_i,
  output logic src_valid_o
);

  localparam int c_LAT_FIFO_WORDS = 4;
  localparam int c_RATIO = colibri_utils::maximum(g_SNK_DATA_WIDTH, g_SRC_DATA_WIDTH) /
                           colibri_utils::minimum(g_SNK_DATA_WIDTH, g_SRC_DATA_WIDTH);
  localparam int c_NUM_WORDS = g_MAX_PACKET_BYTES * g_NUM_PACKETS /
                               (colibri_utils::maximum(g_SNK_DATA_WIDTH, g_SRC_DATA_WIDTH) / 8);
  localparam int c_SNK_WORDS = colibri_utils::maximum(g_SNK_DATA_WIDTH, g_SRC_DATA_WIDTH) *
                               c_NUM_WORDS / g_SNK_DATA_WIDTH;
  localparam int c_SRC_WORDS = colibri_utils::maximum(g_SNK_DATA_WIDTH, g_SRC_DATA_WIDTH) *
                               c_NUM_WORDS / g_SRC_DATA_WIDTH;
  localparam int c_SNK_EMPTY_W = colibri_types::avst_empty_width(g_SNK_DATA_WIDTH, 8);
  localparam int c_SRC_EMPTY_W = colibri_types::avst_empty_width(g_SRC_DATA_WIDTH, 8);
  localparam int c_SIZE_W = colibri_utils::downto_width(
    colibri_utils::log2ceil(g_MAX_PACKET_BYTES * g_NUM_PACKETS)
  );
  localparam int c_SNK_AW = colibri_utils::downto_width(colibri_utils::log2ceil(c_SNK_WORDS));
  localparam int c_SRC_AW = colibri_utils::downto_width(colibri_utils::log2ceil(c_SRC_WORDS));
  localparam int c_PKT_PTR_W = colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_PACKETS));
  localparam int c_PIPE_USED_W = colibri_utils::log2ceil(c_LAT_FIFO_WORDS) + 1;
  localparam int c_KEEP_W = g_SNK_DATA_WIDTH / 8;

  `COLIBRI_AVST_MASTER_T(avst_snk_t, g_SNK_DATA_WIDTH, c_SNK_EMPTY_W);
  `COLIBRI_AVST_MASTER_T(avst_src_t, g_SRC_DATA_WIDTH, c_SRC_EMPTY_W);

  typedef enum logic [1:0] {
    S_IDLE   = 2'd0,
    S_PACKET = 2'd1,
    S_SIZE   = 2'd2,
    S_DROP   = 2'd3
  } snk_fsm_t;

  typedef enum logic {
    SRC_IDLE   = 1'b0,
    SRC_PACKET = 1'b1
  } src_fsm_t;

  typedef struct {
    snk_fsm_t state;
    logic ready;
    int level;
    int size;
    int addr;
    int start;
    int words;
    logic enable;
    logic size_write;
    logic [c_SIZE_W-1:0] wrq;
  } snk_sig_t;

  typedef struct {
    src_fsm_t state;
    logic rdram;
    logic rdpipe;
    logic rdsize;
    int size;
    int empty;
    int words;
    int rdcnt;
    int outcnt;
    int addr;
    avst_src_t avst;
  } src_sig_t;

  localparam avst_src_t c_AVST_INIT = `COLIBRI_AVST_MASTER_INIT;

  logic reset_snk;
  logic reset_src;

  avst_snk_t skid;
  logic [g_SNK_DATA_WIDTH-1:0] skid_data;
  logic [c_SNK_EMPTY_W-1:0] skid_empty;
  logic skid_sop;
  logic skid_eop;
  logic skid_valid;
  logic skid_drop;
  logic [0:0] drop_in;
  logic [0:0] drop_out;

  logic ram_wren;
  logic ram_rden;
  logic [c_SNK_AW-1:0] ram_wraddr;
  logic [c_SRC_AW-1:0] ram_rdaddr;
  logic [g_SNK_DATA_WIDTH-1:0] ram_wrdata;
  logic [g_SRC_DATA_WIDTH-1:0] ram_rddata;

  logic rdram_reg;
  logic [g_SRC_DATA_WIDTH-1:0] pipe_data;
  logic pipe_empty;
  logic pipe_full;
  logic [c_PIPE_USED_W-1:0] pipe_usedw;

  logic size_wrreq_w;
  logic size_rdreq_w;
  logic size_wrempty_w;
  logic size_rdempty_w;
  logic size_wrfull_w;
  logic size_rdfull_w;
  logic size_wrq_valid_w;
  logic [c_PKT_PTR_W-1:0] size_wrusedw_w;
  logic [c_PKT_PTR_W-1:0] size_rdusedw_w;
  logic [c_SIZE_W-1:0] size_data_w;
  logic [c_SIZE_W-1:0] size_wrq_w;
  logic [c_SIZE_W-1:0] size_q_w;

  typedef struct {
    logic wrreq;
    logic rdreq;
    logic wrempty;
    logic rdempty;
    logic wrfull;
    logic rdfull;
    logic wrq_valid;
    logic [c_PKT_PTR_W-1:0] wrusedw;
    logic [c_PKT_PTR_W-1:0] rdusedw;
    logic [c_SIZE_W-1:0] data;
    logic [c_SIZE_W-1:0] wrq;
    logic [c_SIZE_W-1:0] q;
    logic almost_full;
  } fifo_t;

  fifo_t size;
  snk_sig_t snk_rreg;
  snk_sig_t snk_rcmb;
  src_sig_t src_rreg;
  src_sig_t src_rcmb;

  assign skid.data  = skid_data;
  assign skid.empty = skid_empty;
  assign skid.sop   = skid_sop;
  assign skid.eop   = skid_eop;
  assign skid.valid = skid_valid;
  assign drop_in    = snk_drop_i;
  assign skid_drop  = drop_out;

  assign size.wrreq     = size_wrreq_w;
  assign size.rdreq     = size_rdreq_w;
  assign size.wrempty   = size_wrempty_w;
  assign size.rdempty   = size_rdempty_w;
  assign size.wrfull    = size_wrfull_w;
  assign size.rdfull    = size_rdfull_w;
  assign size.wrq_valid = size_wrq_valid_w;
  assign size.wrusedw   = size_wrusedw_w;
  assign size.rdusedw   = size_rdusedw_w;
  assign size.data      = size_data_w;
  assign size.wrq       = size_wrq_w;
  assign size.q         = size_q_w;
  assign size.almost_full = (int'(size_wrusedw_w) < (g_NUM_PACKETS - 2)) ? 1'b0 : 1'b1;

  initial begin
    snk_rreg.state      = S_IDLE;
    snk_rreg.ready      = 1'b0;
    snk_rreg.level      = 0;
    snk_rreg.size       = 0;
    snk_rreg.addr       = 0;
    snk_rreg.start      = 0;
    snk_rreg.words      = 0;
    snk_rreg.enable     = 1'b0;
    snk_rreg.size_write = 1'b0;
    snk_rreg.wrq        = '0;
    src_rreg.state  = SRC_IDLE;
    src_rreg.rdram  = 1'b0;
    src_rreg.rdpipe = 1'b0;
    src_rreg.rdsize = 1'b0;
    src_rreg.size   = 0;
    src_rreg.empty  = 0;
    src_rreg.words  = 0;
    src_rreg.rdcnt  = 0;
    src_rreg.outcnt = 0;
    src_rreg.addr   = 0;
    src_rreg.avst   = c_AVST_INIT;
  end

  synchro_reset snk_reset_inst (
    .clk_i(snk_clk_i),
    .reset_i(reset_i),
    .reset_o(reset_snk)
  );

  synchro_reset src_reset_inst (
    .clk_i(src_clk_i),
    .reset_i(reset_i),
    .reset_o(reset_src)
  );

  // src_keep_o is open in the VHDL.
  // verilator lint_off PINMISSING
  skid_buffer #(
    .g_DATA_WIDTH(g_SNK_DATA_WIDTH)
  ) skid_buffer_inst (
    .clk_i(snk_clk_i),
    .reset_i(reset_snk),
    .snk_data_i(snk_data_i),
    .snk_empty_i(snk_empty_i),
    .snk_keep_i({c_KEEP_W{1'b0}}),
    .snk_sop_i(snk_sop_i),
    .snk_eop_i(snk_eop_i),
    .snk_valid_i(snk_valid_i),
    .snk_ready_o(snk_ready_o),
    .src_data_o(skid_data),
    .src_empty_o(skid_empty),
    .src_sop_o(skid_sop),
    .src_eop_o(skid_eop),
    .src_valid_o(skid_valid),
    .src_ready_i(snk_rcmb.ready)
  );
  // verilator lint_on PINMISSING

  // snk_ready_o and src_valid_o are open in the VHDL.
  // verilator lint_off PINMISSING
  stream_buffer #(
    .g_DATA_WIDTH(1),
    .g_REGISTER_DATAPATH(1'b0)
  ) drop_buf_inst (
    .reset_i(reset_snk),
    .clk_i(snk_clk_i),
    .snk_data_i(drop_in),
    .snk_valid_i(snk_valid_i),
    .src_data_o(drop_out),
    .src_ready_i(snk_rcmb.ready)
  );
  // verilator lint_on PINMISSING

  simple_dpram #(
    .g_A_DATA_WIDTH(g_SNK_DATA_WIDTH),
    .g_B_DATA_WIDTH(g_SRC_DATA_WIDTH),
    .g_N_WORDS(c_NUM_WORDS),
    .g_A_ADDR_WIDTH(c_SNK_AW),
    .g_B_ADDR_WIDTH(c_SRC_AW),
    .g_REGISTER_OUT(1'b1),
    .g_IMPL_STYLE(g_IMPL_STYLE)
  ) main_ram_inst (
    .wrclk_i(snk_clk_i),
    .wren_i(ram_wren),
    .wraddr_i(ram_wraddr),
    .wrdata_i(ram_wrdata),
    .rdclk_i(src_clk_i),
    .rden_i(ram_rden),
    .rdaddr_i(ram_rdaddr),
    .rddata_o(ram_rddata)
  );

  always_ff @(posedge src_clk_i) begin : proc_rdram_reg
    rdram_reg <= src_rreg.rdram;
  end

  fifo #(
    .g_NUM_WORDS(c_LAT_FIFO_WORDS),
    .g_INPUT_WIDTH(g_SRC_DATA_WIDTH),
    .g_ENABLE_FWFT(1'b1)
  ) latency_fifo_inst (
    .clk_i(src_clk_i),
    .reset_i(reset_src),
    .data_i(ram_rddata),
    .wrreq_i(rdram_reg),
    .rdreq_i(src_rcmb.rdpipe),
    .q_o(pipe_data),
    .usedw_o(pipe_usedw),
    .empty_o(pipe_empty),
    .full_o(pipe_full)
  );

  cc_fifo #(
    .g_NUM_WORDS(g_NUM_PACKETS),
    .g_INPUT_WIDTH(c_SIZE_W),
    .g_ENABLE_FWFT(1'b1),
    .g_PEEK_NEXT(1'b1)
  ) size_fifo_inst (
    .reset_i(reset_i),
    .wrclk_i(snk_clk_i),
    .rdclk_i(src_clk_i),
    .data_i(size_data_w),
    .wrreq_i(size_wrreq_w),
    .rdreq_i(size_rdreq_w),
    .q_o(size_q_w),
    .wrusedw_o(size_wrusedw_w),
    .rdusedw_o(size_rdusedw_w),
    .wrempty_o(size_wrempty_w),
    .wrfull_o(size_wrfull_w),
    .rdempty_o(size_rdempty_w),
    .rdfull_o(size_rdfull_w),
    .wrq_o(size_wrq_w),
    .wrq_valid_o(size_wrq_valid_w)
  );

  always_ff @(posedge snk_clk_i) begin : proc_snk_reg
    snk_rreg <= snk_rcmb;
  end

  always_comb begin : proc_write_fsm
    snk_sig_t v_int;
    v_int            = snk_rreg;
    v_int.ready      = 1'b0;
    v_int.size_write = 1'b0;

    if (size.wrq_valid) begin
      v_int.wrq    = size.wrq;
      v_int.words  = int'(colibri_utils::uval#(c_SIZE_W)::div_ceil(size.wrq, g_SNK_DATA_WIDTH / 8));
      v_int.enable = 1'b1;
      if (snk_rreg.enable && (snk_rreg.wrq != size.wrq))
        v_int.level = snk_rreg.level - snk_rreg.words;
    end

    case (snk_rreg.state)
      S_IDLE: begin
        if (snk_rreg.level != c_SNK_WORDS) begin
          if (skid.valid && skid.sop && !skid_drop) begin
            v_int.ready = 1'b1;
            v_int.start = snk_rreg.addr;
            if (snk_rreg.addr != (c_SNK_WORDS - 1))
              v_int.addr = snk_rreg.addr + 1;
            else
              v_int.addr = 0;
            v_int.level = v_int.level + 1;
            if (!skid.eop) begin
              v_int.size  = g_SNK_DATA_WIDTH / 8;
              v_int.state = S_PACKET;
            end else begin
              v_int.size = (g_SNK_DATA_WIDTH / 8) - int'(skid.empty);
              if ((c_RATIO > 1) && (g_SRC_DATA_WIDTH > g_SNK_DATA_WIDTH)) begin
                if (snk_rreg.addr < (c_SNK_WORDS - c_RATIO))
                  v_int.addr = c_RATIO * colibri_utils::div_ceil(snk_rreg.addr, c_RATIO);
                else
                  v_int.addr = 0;
              end
              if (!size.almost_full)
                v_int.size_write = 1'b1;
              else
                v_int.state = S_SIZE;
            end
          end else if (skid.valid) begin
            v_int.ready = 1'b1;
            if (!skid.eop)
              v_int.state = S_DROP;
          end
        end
      end

      S_PACKET: begin
        if (snk_rreg.level != c_SNK_WORDS) begin
          if (skid_drop || snk_drop_i) begin
            v_int.addr  = snk_rreg.start;
            v_int.level = v_int.level - (snk_rreg.size * 8) / g_SNK_DATA_WIDTH;
            v_int.ready = 1'b1;
            if (skid.eop)
              v_int.state = S_IDLE;
            else
              v_int.state = S_DROP;
          end else if (skid.valid) begin
            v_int.ready = 1'b1;
            if (snk_rreg.addr != (c_SNK_WORDS - 1))
              v_int.addr = snk_rreg.addr + 1;
            else
              v_int.addr = 0;
            v_int.level = v_int.level + 1;
            if (!skid.eop) begin
              v_int.size  = snk_rreg.size + (g_SNK_DATA_WIDTH / 8);
              v_int.state = S_PACKET;
            end else begin
              v_int.size = snk_rreg.size + (g_SNK_DATA_WIDTH / 8) - int'(skid.empty);
              if ((c_RATIO > 1) && (g_SRC_DATA_WIDTH > g_SNK_DATA_WIDTH)) begin
                if (snk_rreg.addr < (c_SNK_WORDS - c_RATIO))
                  v_int.addr = c_RATIO * ((snk_rreg.addr / c_RATIO) + 1);
                else
                  v_int.addr = 0;
              end
              if (!size.wrfull) begin
                v_int.size_write = 1'b1;
                v_int.state      = S_IDLE;
              end else begin
                v_int.state = S_SIZE;
              end
            end
          end
        end else begin
          if (size.wrempty) begin
            v_int.addr  = snk_rreg.start;
            v_int.level = v_int.level - (snk_rreg.size * 8) / g_SNK_DATA_WIDTH;
            if (skid.eop)
              v_int.state = S_IDLE;
            else
              v_int.state = S_DROP;
          end
        end
      end

      S_SIZE: begin
        if (!size.wrfull) begin
          v_int.size_write = 1'b1;
          v_int.state      = S_IDLE;
        end
      end

      S_DROP: begin
        v_int.ready = 1'b1;
        if (skid.valid && skid.eop)
          v_int.state = S_IDLE;
      end

      default: begin
      end
    endcase

    if (reset_i) begin
      v_int.state      = S_IDLE;
      v_int.ready      = 1'b0;
      v_int.level      = 0;
      v_int.size       = 0;
      v_int.addr       = 0;
      v_int.start      = 0;
      v_int.words      = 0;
      v_int.enable     = 1'b0;
      v_int.size_write = 1'b0;
      v_int.wrq        = '0;
    end

    snk_rcmb = v_int;
  end

  assign ram_wren     = skid.valid & snk_rcmb.ready;
  assign ram_wraddr   = c_SNK_AW'(snk_rreg.addr);
  assign ram_wrdata   = skid.data;
  assign size_wrreq_w = snk_rreg.size_write;
  assign size_data_w  = c_SIZE_W'(snk_rreg.size);

  always_comb begin : proc_read_fsm
    src_sig_t v_int;
    v_int        = src_rreg;
    v_int.rdsize = 1'b0;
    v_int.rdram  = 1'b0;
    v_int.rdpipe = 1'b0;

    if (src_ready_i)
      v_int.avst = c_AVST_INIT;

    case (src_rreg.state)
      SRC_IDLE: begin
        if (!size.rdempty && !v_int.avst.valid) begin
          v_int.size   = int'(size.q);
          v_int.words  = int'(colibri_utils::uval#(c_SIZE_W)::div_ceil(size.q, g_SRC_DATA_WIDTH / 8));
          v_int.rdcnt  = 0;
          v_int.outcnt = 0;
          if ((c_RATIO > 1) && (g_SNK_DATA_WIDTH > g_SRC_DATA_WIDTH)) begin
            if (src_rreg.addr <= (c_SRC_WORDS - c_RATIO))
              v_int.addr = c_RATIO * colibri_utils::div_ceil(src_rreg.addr, c_RATIO);
            else
              v_int.addr = 0;
          end
          v_int.state = SRC_PACKET;
        end
      end

      SRC_PACKET: begin
        if (int'(pipe_usedw) < (c_LAT_FIFO_WORDS / 2)) begin
          if (v_int.rdcnt == 0)
            v_int.empty = (g_SRC_DATA_WIDTH / 8) * src_rreg.words - src_rreg.size;
          if (src_rreg.rdcnt < src_rreg.words) begin
            v_int.rdram = 1'b1;
            if (src_rreg.addr < (c_SRC_WORDS - 1))
              v_int.addr = src_rreg.addr + 1;
            else
              v_int.addr = 0;
            v_int.rdcnt = src_rreg.rdcnt + 1;
            if (src_rreg.rdcnt == (src_rreg.words - 1))
              v_int.rdsize = 1'b1;
          end
        end

        if (!v_int.avst.valid && !pipe_empty) begin
          v_int.avst = c_AVST_INIT;
          if (src_rreg.outcnt == 0)
            v_int.avst.sop = 1'b1;
          v_int.rdpipe     = 1'b1;
          v_int.avst.valid = 1'b1;
          v_int.avst.data  = pipe_data;
          v_int.outcnt     = src_rreg.outcnt + 1;
          if (src_rreg.outcnt == (src_rreg.words - 1)) begin
            v_int.avst.eop   = 1'b1;
            v_int.avst.empty = c_SRC_EMPTY_W'(v_int.empty);
            v_int.state      = SRC_IDLE;
          end
        end
      end

      default: begin
      end
    endcase

    // Each VUnit test elaborates from a cleared read side. Reset does the
    // same so back-to-back scenarios start at address 0 with valid low.
    if (reset_src) begin
      v_int.state  = SRC_IDLE;
      v_int.rdram  = 1'b0;
      v_int.rdpipe = 1'b0;
      v_int.rdsize = 1'b0;
      v_int.size   = 0;
      v_int.empty  = 0;
      v_int.words  = 0;
      v_int.rdcnt  = 0;
      v_int.outcnt = 0;
      v_int.addr   = 0;
      v_int.avst   = c_AVST_INIT;
    end

    src_rcmb = v_int;
  end

  always_ff @(posedge src_clk_i) begin : proc_src_reg
    src_rreg <= src_rcmb;
  end

  assign ram_rdaddr  = c_SRC_AW'(src_rreg.addr);
  assign ram_rden    = src_rcmb.rdram;
  assign size_rdreq_w = src_rreg.rdsize;
  assign src_sop_o   = src_rreg.avst.sop;
  assign src_eop_o   = src_rreg.avst.eop;
  assign src_data_o  = src_rreg.avst.data;
  assign src_empty_o = src_rreg.avst.empty;
  assign src_size_o  = c_SIZE_W'(src_rreg.size);
  assign src_valid_o = src_rreg.avst.valid;

endmodule
// verilator lint_on MULTITOP
