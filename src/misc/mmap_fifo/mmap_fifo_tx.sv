// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Memory Mapped FIFO to Stream.
// Write a destination id, write data, then write the packet size in bytes.

`timescale 1ns/1ps

module mmap_fifo_tx #(
  parameter int unsigned g_WB_ADDR_WIDTH = 32,
  parameter int unsigned g_WB_DATA_WIDTH = 32,
  parameter int unsigned g_STREAM_DATA_WIDTH = g_WB_DATA_WIDTH,
  // VHDL generic has no default. 16 lets Verilator elaborate a top.
  parameter int unsigned g_NUM_WORDS = 16,
  parameter int unsigned g_NUM_CH = 4,
  parameter bit g_USE_BLOCK_RAM = 1'b0,
  parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()
) (
  input  logic reset_i,
  input  logic clk_i,
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
  output logic intr_o
);

  localparam int c_MAX_WORD_BYTES = colibri_utils::maximum(int'(g_WB_DATA_WIDTH), int'(g_STREAM_DATA_WIDTH)) / 8;
  localparam int c_MAX_BYTES      = int'(g_NUM_WORDS) * c_MAX_WORD_BYTES;
  localparam int c_EMPTY_W        = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8));
  localparam int c_CH_W           = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)));
  localparam int c_USEDW_W        = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_WORDS)));
  localparam int c_TXLEN_W        = colibri_utils::log2ceil(c_MAX_BYTES) + 1;
  localparam int c_STR_BYTES      = int'(g_STREAM_DATA_WIDTH) / 8;
  localparam int c_WB_BYTES       = int'(g_WB_DATA_WIDTH) / 8;

  `COLIBRI_AVST_MASTER_T(avst_t, g_STREAM_DATA_WIDTH, c_EMPTY_W);

  function automatic avst_t avst_init();
    return avst_t'(colibri_types::avst#(g_STREAM_DATA_WIDTH)::master_init());
  endfunction

  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_SOP    = 3'd1,
    S_PACKET = 3'd2,
    S_FLUSH  = 3'd3,
    S_ERROR  = 3'd4
  } fsm_t;

  typedef struct {
    fsm_t state;
    avst_t avst;
    logic ready;
    logic done;
    int   empty;
    int   size;
    int   chan;
    int   words;
  } sig_t;

  function automatic sig_t sig_init();
    sig_t v;
    v.state = S_IDLE;
    v.avst  = avst_init();
    v.ready = 1'b0;
    v.done  = 1'b0;
    v.empty = 0;
    v.size  = 0;
    v.chan  = 0;
    v.words = 0;
    return v;
  endfunction

  logic wb_rack;
  logic wb_rack_reg;
  logic [g_WB_DATA_WIDTH-1:0] wb_odat;
  logic wb_wack;
  logic wb_rerr;
  logic wb_werr;
  logic wb_reset;

  txfifo_csr_pkg::txfifo_csr_in_t  csr_s2m;
  txfifo_csr_pkg::txfifo_csr_out_t csr_m2s;

  logic txwrreq;
  logic [g_STREAM_DATA_WIDTH-1:0] txdata;
  logic txlen_upd;
  logic txlen_ok;
  logic [c_TXLEN_W-1:0] wrlen;
  logic [c_TXLEN_W-1:0] txlen;
  logic [c_CH_W-1:0] txchan;
  logic init_tx;
  logic tle_next_q;
  logic txc_pulse;

  logic wb_tx_empty;
  logic wb_tx_full;
  logic [c_USEDW_W-1:0] wb_tx_usedw;
  logic tx_empty;
  logic tx_full;
  logic [c_USEDW_W-1:0] tx_usedw;
  logic txreset;

  sig_t rreg;
  sig_t rcmb;
  logic fsm_ready;

  // verilator lint_off UNUSEDSIGNAL
  wire _unused_wb = &{1'b0, wb_sel_i, wb_cyc_i, wb_tx_full, tx_full};
  // verilator lint_on UNUSEDSIGNAL

  initial rreg = sig_init();

  synchro_reset synchro_reset_inst (
    .clk_i  (wb_clk_i),
    .reset_i(reset_i),
    .reset_o(wb_reset)
  );

  assign wb_ack_o = wb_rack_reg | wb_wack;
  assign wb_err_o = wb_rerr | wb_werr;

  // verilator lint_off PINCONNECTEMPTY
  txfifo_csr txfifo_csr_inst (
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
    .s_cpuif_rd_data     (wb_odat),
    .s_cpuif_wr_ack      (wb_wack),
    .s_cpuif_wr_err      (wb_werr),
    .hwif_in             (csr_s2m),
    .hwif_out            (csr_m2s)
  );
  // verilator lint_on PINCONNECTEMPTY

  always_ff @(negedge wb_clk_i) begin : proc_wb_fall
    wb_rack_reg <= wb_rack;
    wb_dat_o    <= wb_odat;
  end

  assign intr_o = csr_m2s.isr.intr;

  assign fsm_ready = rcmb.ready;

  if (g_USE_BLOCK_RAM) begin : gen_ram_impl
    cc_ram_fifo #(
      .g_NUM_WORDS   (int'(g_NUM_WORDS)),
      .g_INPUT_WIDTH (int'(g_WB_DATA_WIDTH)),
      .g_OUTPUT_WIDTH(int'(g_STREAM_DATA_WIDTH)),
      .g_ENABLE_FWFT (1'b1),
      .g_IMPL_STYLE  (g_IMPL_STYLE)
    ) tx_fifo_inst (
      .reset_i  (txreset),
      .wrclk_i  (wb_clk_i),
      .rdclk_i  (clk_i),
      .data_i   (csr_m2s.write.data.value),
      .wrreq_i  (txwrreq),
      .rdreq_i  (fsm_ready),
      .q_o      (txdata),
      .wrusedw_o(wb_tx_usedw),
      .rdusedw_o(tx_usedw),
      .wrempty_o(wb_tx_empty),
      .wrfull_o (wb_tx_full),
      .rdempty_o(tx_empty),
      .rdfull_o (tx_full)
    );
  end else begin : gen_ff_impl
    // verilator lint_off PINCONNECTEMPTY
    cc_fifo #(
      .g_NUM_WORDS   (int'(g_NUM_WORDS)),
      .g_INPUT_WIDTH (int'(g_WB_DATA_WIDTH)),
      .g_OUTPUT_WIDTH(int'(g_STREAM_DATA_WIDTH)),
      .g_ENABLE_FWFT (1'b1)
    ) tx_fifo_inst (
      .reset_i    (txreset),
      .wrclk_i    (wb_clk_i),
      .rdclk_i    (clk_i),
      .data_i     (csr_m2s.write.data.value),
      .wrreq_i    (txwrreq),
      .rdreq_i    (fsm_ready),
      .q_o        (txdata),
      .wrusedw_o  (wb_tx_usedw),
      .rdusedw_o  (tx_usedw),
      .wrempty_o  (wb_tx_empty),
      .wrfull_o   (wb_tx_full),
      .rdempty_o  (tx_empty),
      .rdfull_o   (tx_full),
      .wrq_o      (),
      .wrq_valid_o()
    );
    // verilator lint_on PINCONNECTEMPTY
  end

  always_ff @(posedge wb_clk_i) begin : proc_tx_strobes
    txwrreq   <= csr_m2s.write.data.swmod;
    txlen_upd <= csr_m2s.length.bytes.swmod;
  end

  always_comb begin : proc_csr_in
    csr_s2m.isr.wrf.next_q    = wb_tx_full & txwrreq;
    csr_s2m.isr.tle.next_q    = tle_next_q;
    csr_s2m.isr.txc.next_q    = txc_pulse;
    csr_s2m.fill.usedw.next_q = 32'(wb_tx_usedw);
  end

  assign txreset = csr_m2s.ctrl.rst.value | wb_reset;

  always_ff @(posedge wb_clk_i) begin : proc_count_len
    txlen_ok <= 1'b0;
    if (txreset || txlen_upd) begin
      wrlen <= '0;
      tle_next_q <= 1'b0;
      if (wrlen < c_TXLEN_W'(csr_m2s.length.bytes.value))
        tle_next_q <= 1'b1;
      else
        txlen_ok <= txlen_upd;
    end else begin
      tle_next_q <= 1'b0;
      if (txwrreq && !wb_tx_full)
        wrlen <= wrlen + c_TXLEN_W'(c_WB_BYTES);
    end
  end

  always_ff @(posedge wb_clk_i) begin : proc_reg_txlen
    if (txlen_upd) begin
      txlen  <= c_TXLEN_W'(csr_m2s.length.bytes.value);
      txchan <= c_CH_W'(csr_m2s.dst.id.value);
    end
  end

  synchro_pulse txstart_sync_inst (
    .src_clk_i(wb_clk_i),
    .dst_clk_i(clk_i),
    .pulse_i  (txlen_ok),
    .pulse_o  (init_tx)
  );

  synchro_pulse txcomplete_sync_inst (
    .src_clk_i(clk_i),
    .dst_clk_i(wb_clk_i),
    .pulse_i  (rreg.done),
    .pulse_o  (txc_pulse)
  );

  always_ff @(posedge clk_i) begin : proc_tx_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_tx_fsm
    sig_t v_int;
    v_int       = rreg;
    v_int.done  = 1'b0;
    v_int.ready = 1'b0;
    if (src_ready_i)
      v_int.avst = avst_init();

    case (v_int.state)
      S_IDLE: begin
        if (init_tx) begin
          v_int.size  = int'(txlen);
          v_int.chan  = int'(txchan);
          v_int.words = colibri_utils::div_ceil(v_int.size, c_STR_BYTES);
          v_int.empty = v_int.words * c_STR_BYTES - v_int.size;
          v_int.state = S_SOP;
        end
      end
      S_SOP: begin
        if (!tx_empty) begin
          if (!v_int.avst.valid) begin
            v_int.ready      = 1'b1;
            v_int.avst.valid = 1'b1;
            v_int.avst.sop   = 1'b1;
            v_int.avst.data  = txdata;
            v_int.words      = rreg.words - 1;
            if (rreg.words > 1) begin
              v_int.state = S_PACKET;
            end else begin
              v_int.avst.eop   = 1'b1;
              v_int.avst.empty = c_EMPTY_W'(rreg.empty);
              v_int.state      = S_FLUSH;
            end
          end
        end
      end
      S_PACKET: begin
        if (!tx_empty) begin
          if (!v_int.avst.valid) begin
            v_int.ready      = 1'b1;
            v_int.avst.valid = 1'b1;
            v_int.avst.data  = txdata;
            v_int.words      = rreg.words - 1;
            if (rreg.words > 1) begin
              v_int.state = S_PACKET;
            end else begin
              v_int.avst.eop   = 1'b1;
              v_int.avst.empty = c_EMPTY_W'(rreg.empty);
              v_int.state      = S_FLUSH;
            end
          end
        end
      end
      S_FLUSH: begin
        if (src_ready_i) begin
          v_int.state = S_IDLE;
          v_int.done  = 1'b1;
        end
      end
      S_ERROR: begin
      end
      default: v_int.state = S_IDLE;
    endcase

    if (reset_i)
      v_int = sig_init();
    rcmb = v_int;
  end

  assign src_valid_o = rreg.avst.valid;
  assign src_sop_o   = rreg.avst.sop;
  assign src_eop_o   = rreg.avst.eop;
  assign src_empty_o = rreg.avst.empty;
  assign src_data_o  = rreg.avst.data;
  assign src_chan_o  = c_CH_W'(rreg.chan);

endmodule
