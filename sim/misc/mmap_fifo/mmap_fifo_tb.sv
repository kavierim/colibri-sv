// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-check for mmap_fifo. Each VHDL run() is a fresh reset: TX and RX
// simple loops, overflow, a short length, and a read of an empty RX FIFO.

`timescale 1ns/1ps

module mmap_fifo_tb;

  // verilator lint_off REALCVT
  localparam time c_CLK_PERIOD    = 50ns;
  localparam time c_WB_CLK_PERIOD = 20ns;
  // verilator lint_on REALCVT
  localparam int c_NUM_WORDS      = 16;
  localparam int c_NUM_CH         = 4;
  localparam int c_PACKET_SIZE    = (c_NUM_WORDS * 32 / 8) - 1;
  localparam int c_TEST_SIZE      = 10;
  localparam int c_OVF_BYTES      = (32 / 8) * 4;
  localparam int c_POOL           = c_PACKET_SIZE + c_OVF_BYTES;

  localparam logic [31:0] ADDR_TX_CTRL = 32'h00;
  localparam logic [31:0] ADDR_TX_IER  = 32'h04;
  localparam logic [31:0] ADDR_TX_ISR  = 32'h08;
  localparam logic [31:0] ADDR_TX_LEN  = 32'h10;
  localparam logic [31:0] ADDR_TX_DATA = 32'h14;
  localparam logic [31:0] ADDR_TX_DEST = 32'h18;
  localparam logic [31:0] ADDR_RX_CTRL = 32'h20;
  localparam logic [31:0] ADDR_RX_IER  = 32'h24;
  localparam logic [31:0] ADDR_RX_ISR  = 32'h28;
  localparam logic [31:0] ADDR_RX_LEN  = 32'h30;
  localparam logic [31:0] ADDR_RX_DATA = 32'h34;
  localparam logic [31:0] ADDR_RX_SRC  = 32'h38;

  logic reset = 1'b1;
  logic clk   = 1'b0;
  logic wb_clk = 1'b0;
  logic snk_ready;
  logic snk_valid = 1'b0;
  logic snk_sop   = 1'b1;
  logic snk_eop   = 1'b0;
  logic [1:0] snk_empty = '0;
  logic [31:0] snk_data = '0;
  logic [1:0] snk_chan = '0;
  logic src_ready = 1'b1;
  logic src_valid;
  logic src_sop;
  logic src_eop;
  logic [1:0] src_empty;
  logic [31:0] src_data;
  logic [1:0] src_chan;
  logic [31:0] wb_adr = '0;
  logic [31:0] wb_dat_o;
  logic [31:0] wb_dat_i = '0;
  logic wb_we = 1'b0;
  logic [3:0] wb_sel = 4'hF;
  logic wb_stb = 1'b0;
  logic wb_cyc = 1'b0;
  logic wb_ack;
  logic wb_err;
  logic rx_intr;
  logic tx_intr;
  logic intr;

  logic [7:0] cap[0:127];
  int cap_n = 0;
  int pkts = 0;
  logic [1:0] cap_chan = '0;

  assign intr = tx_intr | rx_intr;

  mmap_fifo #(
    .g_WB_ADDR_WIDTH    (32),
    .g_WB_DATA_WIDTH    (32),
    .g_STREAM_DATA_WIDTH(32),
    .g_NUM_WORDS        (c_NUM_WORDS),
    .g_NUM_CH           (c_NUM_CH)
  ) dut (
    .reset_i    (reset),
    .clk_i      (clk),
    .snk_ready_o(snk_ready),
    .snk_valid_i(snk_valid),
    .snk_sop_i  (snk_sop),
    .snk_eop_i  (snk_eop),
    .snk_empty_i(snk_empty),
    .snk_data_i (snk_data),
    .snk_chan_i (snk_chan),
    .src_ready_i(src_ready),
    .src_valid_o(src_valid),
    .src_sop_o  (src_sop),
    .src_eop_o  (src_eop),
    .src_empty_o(src_empty),
    .src_data_o (src_data),
    .src_chan_o (src_chan),
    .wb_clk_i   (wb_clk),
    .wb_adr_i   (wb_adr),
    .wb_dat_o   (wb_dat_o),
    .wb_dat_i   (wb_dat_i),
    .wb_we_i    (wb_we),
    .wb_sel_i   (wb_sel),
    .wb_stb_i   (wb_stb),
    .wb_cyc_i   (wb_cyc),
    .wb_ack_o   (wb_ack),
    .wb_err_o   (wb_err),
    .rx_intr_o  (rx_intr),
    .tx_intr_o  (tx_intr)
  );

  always #(c_CLK_PERIOD / 2) clk = ~clk;
  always #(c_WB_CLK_PERIOD / 2) wb_clk = ~wb_clk;

  always @(posedge clk) begin : proc_cap
    int vb;
    int idx;
    if (reset) begin
      cap_n = 0;
      pkts  = 0;
    end else if (src_valid && src_ready) begin
      vb  = src_eop ? (4 - int'(src_empty)) : 4;
      idx = cap_n;
      for (int b = 0; b < vb; b++)
        cap[idx + b] = src_data[31 - 8 * b -: 8];
      cap_n = idx + vb;
      if (src_sop)
        cap_chan = src_chan;
      if (src_eop)
        pkts = pkts + 1;
    end
  end

  task automatic wb_write(input logic [31:0] addr, input logic [31:0] data);
    int guard;
    @(negedge wb_clk);
    wb_adr   = addr;
    wb_dat_i = data;
    wb_we    = 1'b1;
    wb_stb   = 1'b1;
    wb_cyc   = 1'b1;
    guard    = 0;
    do begin
      @(posedge wb_clk);
      guard++;
      if (guard > 80)
        $fatal(1, "wishbone write timeout @%h", addr);
    end while (!wb_ack);
    @(negedge wb_clk);
    wb_stb = 1'b0;
    wb_cyc = 1'b0;
    wb_we  = 1'b0;
  endtask

  task automatic wb_read(input logic [31:0] addr, output logic [31:0] data);
    int guard;
    @(negedge wb_clk);
    wb_adr = addr;
    wb_we  = 1'b0;
    wb_stb = 1'b1;
    wb_cyc = 1'b1;
    guard  = 0;
    do begin
      @(posedge wb_clk);
      guard++;
      if (guard > 80)
        $fatal(1, "wishbone read timeout @%h", addr);
    end while (!wb_ack);
    data = wb_dat_o;
    @(negedge wb_clk);
    wb_stb = 1'b0;
    wb_cyc = 1'b0;
  endtask

  task automatic wb_check(input logic [31:0] addr, input logic [31:0] exp, input string what);
    logic [31:0] got;
    wb_read(addr, got);
    if (got !== exp)
      $fatal(1, "%s @%h exp %h got %h", what, addr, exp, got);
  endtask

  function automatic logic [31:0] pack_word(input logic [7:0] bytes[0:127], input int idx, input int len);
    logic [31:0] word;
    word = '0;
    for (int k = 0; k < 4; k++) begin
      if ((idx + k) < len)
        word[31 - 8 * k -: 8] = bytes[idx + k];
    end
    return word;
  endfunction

  task automatic write_packet(input logic [7:0] bytes[0:127], input int len, input int dest);
    int words;
    words = (len + 3) / 4;
    wb_write(ADDR_TX_DEST, 32'(dest));
    for (int i = 0; i < words; i++)
      wb_write(ADDR_TX_DATA, pack_word(bytes, i * 4, len));
  endtask

  task automatic send_avst(input logic [7:0] bytes[0:127], input int len, input logic [1:0] chan);
    int nwords;
    int vb;
    logic [31:0] word;
    nwords = (len + 3) / 4;
    snk_chan = chan;
    for (int w = 0; w < nwords; w++) begin
      vb   = ((len - w * 4) > 4) ? 4 : (len - w * 4);
      word = '0;
      for (int b = 0; b < vb; b++)
        word[31 - 8 * b -: 8] = bytes[w * 4 + b];
      @(negedge clk);
      snk_data  = word;
      snk_empty = (w == nwords - 1) ? 2'(4 - vb) : 2'b00;
      snk_sop   = (w == 0);
      snk_eop   = (w == nwords - 1);
      snk_valid = 1'b1;
      do @(posedge clk); while (!snk_ready);
    end
    @(negedge clk);
    snk_valid = 1'b0;
    snk_sop   = 1'b1;
    snk_eop   = 1'b0;
    snk_empty = '0;
  endtask

  task automatic expect_avst(input logic [7:0] bytes[0:127], input int len, input logic [1:0] chan);
    int seen;
    int base;
    int guard;
    seen  = pkts;
    base  = cap_n;
    guard = 0;
    while (pkts == seen) begin
      @(posedge clk);
      guard++;
      if (guard > 800)
        $fatal(1, "AVST timeout");
    end
    @(posedge clk);
    if (cap_chan !== chan)
      $fatal(1, "channel exp %0d got %0d", chan, cap_chan);
    if ((cap_n - base) != len)
      $fatal(1, "AVST length exp %0d got %0d", len, cap_n - base);
    for (int i = 0; i < len; i++) begin
      if (cap[base + i] !== bytes[i])
        $fatal(1, "AVST byte %0d exp %02x got %02x", i, bytes[i], cap[base + i]);
    end
  endtask

  task automatic wait_intr(input int max_cycles);
    int guard;
    logic [31:0] isr;
    logic [31:0] ier;
    guard = 0;
    while (!intr) begin
      @(posedge wb_clk);
      guard++;
      if (guard > max_cycles) begin
        wb_read(ADDR_TX_IER, ier);
        wb_read(ADDR_TX_ISR, isr);
        $fatal(1, "interrupt timeout tx=%b rx=%b ier=%h isr=%h", tx_intr, rx_intr, ier, isr);
      end
    end
  endtask

  task automatic init_dut();
    wb_write(ADDR_TX_CTRL, 32'h1);
    wb_write(ADDR_TX_IER, 32'h0);
    wb_write(ADDR_TX_ISR, 32'hFFFFFFF);
    wb_write(ADDR_RX_IER, 32'h0);
    wb_write(ADDR_RX_ISR, 32'hFFFFFFF);
    repeat (8) @(posedge wb_clk);
  endtask

  task automatic hw_reset();
    reset = 1'b1;
    snk_valid = 1'b0;
    snk_sop = 1'b1;
    repeat (4) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (8) @(posedge wb_clk);
  endtask

  task automatic fill_pool(output logic [7:0] bytes[0:127]);
    for (int i = 0; i < c_POOL; i++)
      bytes[i] = 8'($urandom_range(0, 255));
  endtask

  initial begin : proc_main
    logic [7:0] pool[0:127];
    logic [7:0] pkt[0:127];
    int v_size;
    int v_chan;
    logic [31:0] got;
    int words;

    void'($urandom(32'hC011_F107));
    hw_reset();
    init_dut();
    fill_pool(pool);

    // tx_simple
    for (int i = 0; i < c_TEST_SIZE; i++) begin
      v_size = $urandom_range(1, c_PACKET_SIZE);
      v_chan = $urandom_range(0, c_NUM_CH - 1);
      for (int b = 0; b < v_size; b++)
        pkt[b] = pool[b];
      wb_write(ADDR_TX_IER, 32'h1);
      write_packet(pkt, v_size, v_chan);
      wb_write(ADDR_TX_LEN, 32'(v_size));
      expect_avst(pkt, v_size, 2'(v_chan));
      wait_intr(50);
      wb_check(ADDR_TX_ISR, 32'h1, "TX complete");
      wb_write(ADDR_TX_ISR, 32'hF);
    end

    hw_reset();
    init_dut();
    // tx_overflow
    v_size = $urandom_range(c_PACKET_SIZE + 1, c_PACKET_SIZE + c_OVF_BYTES);
    wb_write(ADDR_TX_IER, 32'h2);
    write_packet(pool, v_size, 0);
    wb_write(ADDR_TX_LEN, 32'(v_size));
    wait_intr(50);
    wb_check(ADDR_TX_ISR, 32'h2, "TX overflow");

    hw_reset();
    init_dut();
    // tx_wrong_size
    v_size = $urandom_range(1, c_PACKET_SIZE - 20);
    wb_write(ADDR_TX_IER, 32'h4);
    write_packet(pool, v_size, 0);
    wb_write(ADDR_TX_LEN, 32'(v_size + 10));
    wait_intr(500);
    wb_check(ADDR_TX_ISR, 32'h4, "TX length error");

    hw_reset();
    init_dut();
    // rx_simple
    for (int i = 0; i < c_TEST_SIZE; i++) begin
      // The RX FSM accepts another word only while usedw < g_NUM_WORDS-2.
      // A 63-byte packet is 16 words and raises overflow on an empty FIFO.
      v_size = $urandom_range(1, (c_NUM_WORDS - 2) * 4);
      v_chan = $urandom_range(0, c_NUM_CH - 1);
      for (int b = 0; b < v_size; b++)
        pkt[b] = pool[b];
      wb_write(ADDR_RX_IER, 32'h1);
      send_avst(pkt, v_size, 2'(v_chan));
      wait_intr(50);
      wb_check(ADDR_RX_ISR, 32'h1, "RX complete");
      wb_write(ADDR_RX_ISR, 32'h1);
      wb_check(ADDR_RX_LEN, 32'(v_size), "RX length");
      wb_check(ADDR_RX_SRC, 32'(v_chan), "RX source");
      words = (v_size + 3) / 4;
      for (int w = 0; w < words; w++) begin
        wb_read(ADDR_RX_DATA, got);
        if (got !== pack_word(pkt, w * 4, v_size))
          $fatal(1, "RX word %0d exp %h got %h", w, pack_word(pkt, w * 4, v_size), got);
      end
    end

    hw_reset();
    init_dut();
    // rx_overflow
    wb_write(ADDR_RX_IER, 32'h3);
    v_size = $urandom_range(c_PACKET_SIZE + 1, c_PACKET_SIZE + c_OVF_BYTES);
    send_avst(pool, v_size, 2'b00);
    wait_intr(500);
    wb_check(ADDR_RX_ISR, 32'h2, "RX overflow");

    hw_reset();
    init_dut();
    // rx_empty
    wb_write(ADDR_RX_IER, 32'h4);
    wb_read(ADDR_RX_DATA, got);
    wait_intr(50);
    wb_check(ADDR_RX_ISR, 32'h4, "RX empty");

    $display("PASS mmap_fifo_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #10ms;
    $fatal(1, "mmap_fifo_tb watchdog");
  end

endmodule
