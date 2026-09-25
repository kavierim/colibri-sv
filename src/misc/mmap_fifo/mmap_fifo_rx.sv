// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Stream to Memory Mapped FIFO.
// An RX-complete interrupt is followed by optional channel and size reads,
// then data reads.

`timescale 1ns/1ps

module mmap_fifo_rx #(
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
  output logic snk_ready_o,
  input  logic snk_valid_i,
  input  logic snk_sop_i,
  input  logic snk_eop_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_STREAM_DATA_WIDTH) / 8))-1:0] snk_empty_i,
  input  logic [g_STREAM_DATA_WIDTH-1:0] snk_data_i,
  input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)))-1:0] snk_chan_i,
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
  localparam int c_CH_W           = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_CH)));
  localparam int c_USEDW_W        = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_NUM_WORDS)));
  localparam int c_RXLEN_W        = colibri_utils::log2ceil(c_MAX_BYTES) + 1;
  localparam int c_STR_BYTES      = int'(g_STREAM_DATA_WIDTH) / 8;

  typedef enum logic [1:0] {
    S_IDLE     = 2'd0,
    S_PACKET   = 2'd1,
    S_COMPLETE = 2'd2,
    S_ERROR    = 2'd3
  } fsm_t;

  typedef struct {
    fsm_t state;
    logic ready;
    logic done;
    logic rwf;
    int   empty;
    int   size;
    int   chan;
  } sig_t;

  function automatic sig_t sig_init();
    sig_t v;
    v.state = S_IDLE;
    v.ready = 1'b0;
    v.done  = 1'b0;
    v.rwf   = 1'b0;
    v.empty = 0;
    v.size  = 0;
    v.chan  = 0;
    return v;
  endfunction

  logic wb_rack;
  logic wb_rack_reg;
  logic [g_WB_DATA_WIDTH-1:0] wb_odat;
  logic wb_wack;
  logic wb_rerr;
  logic wb_werr;
  logic wb_reset;

  rxfifo_csr_pkg::rxfifo_csr_in_t  csr_s2m;
  rxfifo_csr_pkg::rxfifo_csr_out_t csr_m2s;

  logic wrreq;
  logic rxrreq;
  logic [g_WB_DATA_WIDTH-1:0] rxdata;
  logic [c_RXLEN_W-1:0] rxlen;
  logic [c_CH_W-1:0] rxchan;
  logic rxdone;
  logic rxc_pulse;
  logic rwf_pulse;
  logic [31:0] length_bytes_next_q;
  logic [31:0] src_id_next_q;

  logic rx_empty;
  logic rx_full;
  logic [c_USEDW_W-1:0] rx_usedw;
  logic wb_rx_empty;
  logic wb_rx_full;
  logic [c_USEDW_W-1:0] wb_rx_usedw;
  logic rxreset;
  logic fifo_reset;

  sig_t rreg;
  sig_t rcmb;

  // verilator lint_off UNUSEDSIGNAL
  wire _unused_wb = &{1'b0, wb_sel_i, wb_cyc_i, rx_full, wb_rx_full};
  // verilator lint_on UNUSEDSIGNAL

  initial begin
    rreg = sig_init();
    length_bytes_next_q = '0;
    src_id_next_q = '0;
  end

  synchro_reset synchro_reset_inst (
    .clk_i  (wb_clk_i),
    .reset_i(reset_i),
    .reset_o(wb_reset)
  );

  synchro_reset synchro_wbreset_inst (
    .clk_i  (clk_i),
    .reset_i(csr_m2s.ctrl.rst.value),
    .reset_o(fifo_reset)
  );

  assign wb_ack_o = wb_rack_reg | wb_wack;
  assign wb_err_o = wb_rerr | wb_werr;

  // verilator lint_off PINCONNECTEMPTY
  rxfifo_csr rxfifo_csr_inst (
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

  if (g_USE_BLOCK_RAM) begin : gen_ram_fifo
    cc_ram_fifo #(
      .g_NUM_WORDS   (int'(g_NUM_WORDS)),
      .g_INPUT_WIDTH (int'(g_STREAM_DATA_WIDTH)),
      .g_OUTPUT_WIDTH(int'(g_WB_DATA_WIDTH)),
      .g_ENABLE_FWFT (1'b1),
      .g_IMPL_STYLE  (g_IMPL_STYLE)
    ) rx_fifo_inst (
      .reset_i  (rxreset),
      .wrclk_i  (clk_i),
      .rdclk_i  (wb_clk_i),
      .data_i   (snk_data_i),
      .wrreq_i  (wrreq),
      .rdreq_i  (rxrreq),
      .q_o      (rxdata),
      .wrusedw_o(rx_usedw),
      .rdusedw_o(wb_rx_usedw),
      .wrempty_o(rx_empty),
      .wrfull_o (rx_full),
      .rdempty_o(wb_rx_empty),
      .rdfull_o (wb_rx_full)
    );
  end else begin : gen_ff_fifo
    // verilator lint_off PINCONNECTEMPTY
    cc_fifo #(
      .g_NUM_WORDS   (int'(g_NUM_WORDS)),
      .g_INPUT_WIDTH (int'(g_STREAM_DATA_WIDTH)),
      .g_OUTPUT_WIDTH(int'(g_WB_DATA_WIDTH)),
      .g_ENABLE_FWFT (1'b1)
    ) rx_fifo_inst (
      .reset_i    (rxreset),
      .wrclk_i    (clk_i),
      .rdclk_i    (wb_clk_i),
      .data_i     (snk_data_i),
      .wrreq_i    (wrreq),
      .rdreq_i    (rxrreq),
      .q_o        (rxdata),
      .wrusedw_o  (rx_usedw),
      .rdusedw_o  (wb_rx_usedw),
      .wrempty_o  (rx_empty),
      .wrfull_o   (rx_full),
      .rdempty_o  (wb_rx_empty),
      .rdfull_o   (wb_rx_full),
      .wrq_o      (),
      .wrq_valid_o()
    );
    // verilator lint_on PINCONNECTEMPTY
  end

  assign wrreq  = snk_valid_i & snk_ready_o;
  assign rxrreq = csr_m2s.read.data.swacc;
  assign rxreset = fifo_reset | reset_i;

  // VHDL `next_q <= value when rxc` leaves the target unchanged otherwise.
  // verilator lint_off LATCH
  always_latch begin : proc_rx_snapshot
    if (rxc_pulse) begin
      length_bytes_next_q = 32'(rxlen);
      src_id_next_q       = 32'(rxchan);
    end
  end
  // verilator lint_on LATCH

  always_comb begin : proc_csr_in
    csr_s2m.isr.rxc.next_q       = rxc_pulse;
    csr_s2m.isr.rwf.next_q       = rwf_pulse;
    csr_s2m.isr.rwe.next_q       = wb_rx_empty & csr_m2s.read.data.swacc;
    csr_s2m.fill.usedw.next_q    = 32'(wb_rx_usedw);
    csr_s2m.length.bytes.next_q  = length_bytes_next_q;
    csr_s2m.read.data.next_q     = 32'(rxdata);
    csr_s2m.src.id.next_q        = src_id_next_q;
  end

  assign snk_ready_o = rcmb.ready;

  always_ff @(posedge clk_i) begin : proc_rx_reg
    rreg <= rcmb;
  end

  always_comb begin : proc_rx_fsm
    sig_t v_int;
    v_int      = rreg;
    v_int.done = 1'b0;
    v_int.ready = 1'b0;
    v_int.rwf  = 1'b0;

    case (v_int.state)
      S_IDLE: begin
        v_int.size = 0;
        if (snk_sop_i && snk_valid_i) begin
          if (!rx_full) begin
            v_int.ready = 1'b1;
            v_int.chan  = int'(snk_chan_i);
            if (snk_eop_i) begin
              v_int.size  = c_STR_BYTES - int'(snk_empty_i);
              v_int.done  = 1'b1;
              v_int.state = S_COMPLETE;
            end else begin
              v_int.state = S_PACKET;
              v_int.size  = c_STR_BYTES;
            end
          end else begin
            v_int.rwf = 1'b1;
          end
        end
      end
      S_PACKET: begin
        if (snk_valid_i) begin
          if (int'(rx_usedw) < int'(g_NUM_WORDS) - 2) begin
            v_int.ready = 1'b1;
            if (snk_eop_i) begin
              v_int.size  = rreg.size + c_STR_BYTES - int'(snk_empty_i);
              v_int.done  = 1'b1;
              v_int.state = S_COMPLETE;
            end else begin
              v_int.size  = rreg.size + c_STR_BYTES;
              v_int.state = S_PACKET;
            end
          end else begin
            v_int.rwf   = 1'b1;
            v_int.state = S_ERROR;
          end
        end
      end
      S_COMPLETE: begin
        v_int.done = 1'b1;
        if (rx_empty) begin
          v_int.done  = 1'b0;
          v_int.state = S_IDLE;
        end
      end
      S_ERROR: begin
        v_int.ready = 1'b1;
      end
      default: v_int.state = S_IDLE;
    endcase

    if (rxreset)
      v_int = sig_init();
    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_rxdone
    rxdone <= rreg.done;
  end

  always_ff @(posedge clk_i) begin : proc_reg_rxcdc
    if (rxdone) begin
      rxlen  <= c_RXLEN_W'(rreg.size);
      rxchan <= c_CH_W'(rreg.chan);
    end
  end

  synchro_pulse rxdone_sync_inst (
    .src_clk_i(clk_i),
    .dst_clk_i(wb_clk_i),
    .pulse_i  (rxdone),
    .pulse_o  (rxc_pulse)
  );

  synchro_pulse rwf_sync_inst (
    .src_clk_i(clk_i),
    .dst_clk_i(wb_clk_i),
    .pulse_i  (rreg.rwf),
    .pulse_o  (rwf_pulse)
  );

endmodule
