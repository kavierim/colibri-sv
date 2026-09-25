// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Memory Mapped Stream FIFO.
// Wishbone slave in front of full-duplex Avalon-ST packet streams.

`timescale 1ns/1ps

module mmap_fifo #(
  parameter int unsigned g_WB_ADDR_WIDTH = 32,
  parameter int unsigned g_WB_DATA_WIDTH = 32,
  parameter int unsigned g_STREAM_DATA_WIDTH = g_WB_DATA_WIDTH,
  // VHDL generic has no default. 16 lets Verilator elaborate this top.
  parameter int unsigned g_NUM_WORDS = 16,
  parameter int unsigned g_NUM_CH = 4,
  parameter bit g_USE_BLOCK_RAM = 1'b0,
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic reset_i,
  input  logic clk_i,
  output logic snk_ready_o,
  input  logic snk_valid_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8))-1:0] snk_empty_i,
  input  logic [g_STREAM_DATA_WIDTH-1:0] snk_data_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)))-1:0] snk_chan_i,
  input  logic src_ready_i,
  output logic src_valid_o,
  output logic src_sop_o,
  output logic src_eop_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8))-1:0] src_empty_o,
  output logic [g_STREAM_DATA_WIDTH-1:0] src_data_o,
  output logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)))-1:0] src_chan_o,
  input  logic wb_clk_i,
  input  logic [g_WB_ADDR_WIDTH-1:0] wb_adr_i,
  output logic [g_WB_DATA_WIDTH-1:0] wb_dat_o,
  input  logic [g_WB_DATA_WIDTH-1:0] wb_dat_i,
  input  logic wb_we_i,
  input  logic [colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)-1:0] wb_sel_i,
  input  logic wb_stb_i,
  input  logic wb_cyc_i,
  output logic wb_ack_o,
  output logic wb_err_o,
  output logic rx_intr_o,
  output logic tx_intr_o
);

  localparam int c_SEL_W = colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8);

  logic wb_rack;
  logic wb_wack;
  logic wb_rerr;
  logic wb_werr;
  logic wb_reset;

  mmap_fifo_csr_pkg::mmap_fifo_csr_in_t  csr_s2m;
  mmap_fifo_csr_pkg::mmap_fifo_csr_out_t csr_m2s;

  logic [g_WB_ADDR_WIDTH-1:0] wbtx_adr;
  logic [g_WB_DATA_WIDTH-1:0] wbtx_idat;
  logic [g_WB_DATA_WIDTH-1:0] wbtx_odat;
  logic                       wbtx_we;
  logic                       wbtx_stb;
  logic                       wbtx_ack;

  logic [g_WB_ADDR_WIDTH-1:0] wbrx_adr;
  logic [g_WB_DATA_WIDTH-1:0] wbrx_idat;
  logic [g_WB_DATA_WIDTH-1:0] wbrx_odat;
  logic                       wbrx_we;
  logic                       wbrx_stb;
  logic                       wbrx_ack;

  // verilator lint_off UNUSEDSIGNAL
  wire _unused_wb = &{1'b0, wb_sel_i, wb_cyc_i};
  // verilator lint_on UNUSEDSIGNAL

  synchro_reset synchro_reset_inst (
    .clk_i  (wb_clk_i),
    .reset_i(reset_i),
    .reset_o(wb_reset)
  );

  assign wb_ack_o = wb_rack | wb_wack;
  assign wb_err_o = wb_rerr | wb_werr;

  // verilator lint_off PINCONNECTEMPTY
  mmap_fifo_csr mmap_fifo_csr_inst (
    .clk                 (wb_clk_i),
    .rst                 (wb_reset),
    .s_cpuif_req         (wb_stb_i),
    .s_cpuif_req_is_wr   (wb_we_i),
    .s_cpuif_addr        (g_WB_ADDR_WIDTH'(wb_adr_i)),
    .s_cpuif_wr_data     (wb_dat_i),
    .s_cpuif_wr_biten    ('1),
    .s_cpuif_req_stall_wr(),
    .s_cpuif_req_stall_rd(),
    .s_cpuif_rd_ack      (wb_rack),
    .s_cpuif_rd_err      (wb_rerr),
    .s_cpuif_rd_data     (wb_dat_o),
    .s_cpuif_wr_ack      (wb_wack),
    .s_cpuif_wr_err      (wb_werr),
    .hwif_in             (csr_s2m),
    .hwif_out            (csr_m2s)
  );
  // verilator lint_on PINCONNECTEMPTY

  assign wbtx_adr  = g_WB_ADDR_WIDTH'(csr_m2s.tx.addr);
  assign wbtx_odat = csr_m2s.tx.wr_data;
  assign wbtx_we   = csr_m2s.tx.req_is_wr;
  assign wbtx_stb  = csr_m2s.tx.req;

  // verilator lint_off PINCONNECTEMPTY
  mmap_fifo_tx #(
    .g_WB_ADDR_WIDTH    (g_WB_ADDR_WIDTH),
    .g_WB_DATA_WIDTH    (g_WB_DATA_WIDTH),
    .g_STREAM_DATA_WIDTH(g_STREAM_DATA_WIDTH),
    .g_NUM_WORDS        (g_NUM_WORDS),
    .g_NUM_CH           (g_NUM_CH),
    .g_USE_BLOCK_RAM    (g_USE_BLOCK_RAM),
    .g_IMPL_STYLE       (g_IMPL_STYLE)
  ) mmap_fifo_tx_inst (
    .reset_i    (reset_i),
    .clk_i      (clk_i),
    .src_ready_i(src_ready_i),
    .src_valid_o(src_valid_o),
    .src_sop_o  (src_sop_o),
    .src_eop_o  (src_eop_o),
    .src_empty_o(src_empty_o),
    .src_data_o (src_data_o),
    .src_chan_o (src_chan_o),
    .wb_clk_i   (wb_clk_i),
    .wb_adr_i   (wbtx_adr),
    .wb_dat_o   (wbtx_idat),
    .wb_dat_i   (wbtx_odat),
    .wb_we_i    (wbtx_we),
    .wb_sel_i   ({c_SEL_W{1'b0}}),
    .wb_stb_i   (wbtx_stb),
    .wb_cyc_i   (1'b0),
    .wb_ack_o   (wbtx_ack),
    .wb_err_o   (),
    .intr_o     (tx_intr_o)
  );
  // verilator lint_on PINCONNECTEMPTY

  assign wbrx_adr  = g_WB_ADDR_WIDTH'(csr_m2s.rx.addr);
  assign wbrx_odat = csr_m2s.rx.wr_data;
  assign wbrx_we   = csr_m2s.rx.req_is_wr;
  assign wbrx_stb  = csr_m2s.rx.req;

  // One comb block: Verilator treats the whole csr_s2m struct as one variable.
  always_comb begin : proc_ack
    csr_s2m.tx.rd_data = wbtx_idat;
    csr_s2m.tx.wr_ack  = wbtx_ack & wbtx_we;
    csr_s2m.tx.rd_ack  = wbtx_ack & ~wbtx_we;
    csr_s2m.rx.rd_data = wbrx_idat;
    csr_s2m.rx.wr_ack  = wbrx_ack & wbrx_we;
    csr_s2m.rx.rd_ack  = wbrx_ack & ~wbrx_we;
  end

  // verilator lint_off PINCONNECTEMPTY
  mmap_fifo_rx #(
    .g_WB_ADDR_WIDTH    (g_WB_ADDR_WIDTH),
    .g_WB_DATA_WIDTH    (g_WB_DATA_WIDTH),
    .g_STREAM_DATA_WIDTH(g_STREAM_DATA_WIDTH),
    .g_NUM_WORDS        (g_NUM_WORDS),
    .g_NUM_CH           (g_NUM_CH),
    .g_USE_BLOCK_RAM    (g_USE_BLOCK_RAM),
    .g_IMPL_STYLE       (g_IMPL_STYLE)
  ) mmap_fifo_rx_inst (
    .reset_i    (reset_i),
    .clk_i      (clk_i),
    .snk_ready_o(snk_ready_o),
    .snk_valid_i(snk_valid_i),
    .snk_sop_i  (snk_sop_i),
    .snk_eop_i  (snk_eop_i),
    .snk_empty_i(snk_empty_i),
    .snk_data_i (snk_data_i),
    .snk_chan_i (snk_chan_i),
    .wb_clk_i   (wb_clk_i),
    .wb_adr_i   (wbrx_adr),
    .wb_dat_o   (wbrx_idat),
    .wb_dat_i   (wbrx_odat),
    .wb_we_i    (wbrx_we),
    .wb_sel_i   ({c_SEL_W{1'b0}}),
    .wb_stb_i   (wbrx_stb),
    .wb_cyc_i   (1'b0),
    .wb_ack_o   (wbrx_ack),
    .wb_err_o   (),
    .intr_o     (rx_intr_o)
  );
  // verilator lint_on PINCONNECTEMPTY

endmodule
