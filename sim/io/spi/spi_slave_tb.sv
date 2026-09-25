// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// spi_slave scenarios from spi_slave_tb.vhdl and sim/io/spi/run.py.
// The testbench is the SPI master. Bit time is 50 system clocks, chip-select
// gaps are 5 clocks, matching the UVVM slave harness. tx_only and rx_only
// cover 0..255 at CPOL=0 CPHA=0. tx_rx covers the same cross as the master
// test at all four CPOL/CPHA combinations. rx_only waits 50 ns once.
`timescale 1ns/1ps

module spi_slave_tb;
  localparam time c_CLK_PERIOD = time'(25ns);
  localparam time c_SPI_BIT = time'(1250ns);
  localparam time c_SPI_GAP = time'(125ns);
  localparam int c_WORD = 8;
  localparam int c_N = 4;
  localparam bit c_CPHA[4] = '{1'b0, 1'b0, 1'b1, 1'b1};
  localparam bit c_CPOL[4] = '{1'b0, 1'b1, 1'b0, 1'b1};

  logic clk = 1'b0;
  logic tb_sck[4];
  logic tb_mosi[4];
  logic tb_cs_n[4];
  logic miso[4];
  logic [c_WORD-1:0] src_data[4];
  logic src_valid[4];
  logic [c_WORD-1:0] snk_data[4];
  logic snk_valid[4];
  logic snk_ready[4];
  logic [7:0] src_q[4][$];
  logic [7:0] cov_byte[256];
  logic [7:0] cov_tx[512];
  logic [7:0] cov_rx[512];
  bit tb_done = 1'b0;

  always #(c_CLK_PERIOD / 2) clk = ~clk;

  for (genvar gi = 0; gi < c_N; gi++) begin : gen_slave
    localparam bit c_POL = c_CPOL[gi];
    localparam bit c_PHA = c_CPHA[gi];
    spi_slave #(
      .g_WORD_SIZE(c_WORD),
      .g_SCK_POLARITY(c_POL),
      .g_SCK_PHASE(c_PHA)
    ) dut (
      .clk_i(clk),
      .miso_o(miso[gi]),
      .mosi_i(tb_mosi[gi]),
      .cs_n_i(tb_cs_n[gi]),
      .sck_i(tb_sck[gi]),
      .src_data_o(src_data[gi]),
      .src_valid_o(src_valid[gi]),
      .snk_data_i(snk_data[gi]),
      .snk_valid_i(snk_valid[gi]),
      .snk_ready_o(snk_ready[gi])
    );

    always @(posedge clk) begin
      if (src_valid[gi])
        src_q[gi].push_back(src_data[gi]);
    end
  end

  initial begin
    #80ms;
    if (!tb_done)
      $fatal(1, "spi_slave_tb watchdog");
  end

  function automatic string mode_str(input int id);
    return $sformatf("CPOL=%0d CPHA=%0d", c_CPOL[id], c_CPHA[id]);
  endfunction

  task automatic send_snk(input int id, input logic [7:0] data);
    int spins;
    @(negedge clk);
    snk_data[id]  = data;
    snk_valid[id] = 1'b1;
    spins = 0;
    forever begin
      @(posedge clk);
      if (snk_ready[id]) begin
        @(negedge clk);
        snk_valid[id] = 1'b0;
        return;
      end
      spins++;
      if (spins > 10000)
        $fatal(1, "snk ready timeout %s", mode_str(id));
    end
  endtask

  task automatic pop_src(input int id, output logic [7:0] data);
    int spins;
    spins = 0;
    while (src_q[id].size() == 0) begin
      @(posedge clk);
      spins++;
      if (spins > 20000)
        $fatal(1, "src timeout %s", mode_str(id));
    end
    data = src_q[id].pop_front();
  endtask

  // SPI master BFM. Leading edge is the first toggle away from CPOL.
  task automatic spi_host_xfer(
    input int id,
    input logic [7:0] mosi_byte,
    output logic [7:0] miso_byte
  );
    tb_mosi[id]  = mosi_byte[7];
    tb_sck[id]   = c_CPOL[id];
    tb_cs_n[id]  = 1'b0;
    #(c_SPI_GAP);
    miso_byte = '0;
    for (int i = 0; i < 8; i++) begin
      if (!c_CPHA[id]) begin
        #(c_SPI_BIT / 2);
        tb_sck[id] = ~tb_sck[id];
        #1ns;
        miso_byte = {miso_byte[6:0], miso[id]};
        #(c_SPI_BIT / 2 - 1ns);
        tb_sck[id] = ~tb_sck[id];
        if (i != 7)
          tb_mosi[id] = mosi_byte[6-i];
      end else begin
        tb_mosi[id] = mosi_byte[7-i];
        #(c_SPI_BIT / 2);
        tb_sck[id] = ~tb_sck[id];
        #(c_SPI_BIT / 2);
        tb_sck[id] = ~tb_sck[id];
        #1ns;
        miso_byte = {miso_byte[6:0], miso[id]};
        // MOSI is sampled after the SCK synchronizer. Keep the bit until then.
        #(c_CLK_PERIOD * 8);
      end
    end
    #(c_SPI_GAP);
    tb_cs_n[id] = 1'b1;
    tb_sck[id]  = c_CPOL[id];
    #(c_SPI_GAP);
  endtask

  task automatic shuffle_bytes(input int n);
    for (int i = n - 1; i > 0; i--) begin
      int j;
      logic [7:0] tmp;
      j = $urandom_range(i, 0);
      tmp = cov_byte[i];
      cov_byte[i] = cov_byte[j];
      cov_byte[j] = tmp;
    end
  endtask

  task automatic shuffle_pairs(input int n);
    for (int i = n - 1; i > 0; i--) begin
      int j;
      logic [7:0] ta;
      logic [7:0] tb;
      j = $urandom_range(i, 0);
      ta = cov_tx[i];
      tb = cov_rx[i];
      cov_tx[i] = cov_tx[j];
      cov_rx[i] = cov_rx[j];
      cov_tx[j] = ta;
      cov_rx[j] = tb;
    end
  endtask

  task automatic run_one(
    input int id,
    input logic [7:0] mosi_byte,
    input logic [7:0] miso_exp,
    input bit preload,
    input bit check_src,
    input bit check_miso
  );
    logic [7:0] got_miso;
    logic [7:0] got_src;
    // Ready stays low while CS is high (the DUT re-inits). Present the byte
    // before CS; the slave samples it once CS has been synchronized.
    if (preload) begin
      snk_data[id] = miso_exp;
      snk_valid[id] = 1'b1;
    end else begin
      snk_valid[id] = 1'b0;
    end
    spi_host_xfer(id, mosi_byte, got_miso);
    snk_valid[id] = 1'b0;
    pop_src(id, got_src);
    if (check_miso && got_miso !== miso_exp)
      $fatal(1, "MISO %s got=0x%02h exp=0x%02h", mode_str(id), got_miso, miso_exp);
    if (check_src && got_src !== mosi_byte)
      $fatal(1, "src %s got=0x%02h exp=0x%02h", mode_str(id), got_src, mosi_byte);
  endtask

  task automatic run_tx_rx(input int id);
    for (int i = 0; i < 512; i++) begin
      // Slave sends cov_tx[i] (stream in). Master sends cov_rx[i] on MOSI.
      run_one(id, cov_rx[i], cov_tx[i], 1'b1, 1'b1, 1'b1);
      if (i % 128 == 0)
        $display("spi_slave tx_rx %s %0d/512", mode_str(id), i);
    end
    $display("spi_slave tx_rx %s done", mode_str(id));
  endtask

  initial begin
    int n;
    for (int i = 0; i < c_N; i++) begin
      tb_cs_n[i]   = 1'b1;
      tb_sck[i]    = c_CPOL[i];
      tb_mosi[i]   = 1'b0;
      snk_valid[i] = 1'b0;
      snk_data[i]  = '0;
    end
    repeat (8) @(posedge clk);

    for (int i = 0; i < 256; i++)
      cov_byte[i] = 8'(i);
    shuffle_bytes(256);

    $display("spi_slave tx_only");
    for (int i = 0; i < 256; i++) begin
      run_one(0, cov_byte[i], 8'h00, 1'b0, 1'b1, 1'b0);
      if (i % 64 == 0)
        $display("spi_slave tx_only %0d/256", i);
    end

    $display("spi_slave rx_only");
    #50ns;
    for (int i = 0; i < 256; i++) begin
      run_one(0, 8'h00, cov_byte[i], 1'b1, 1'b0, 1'b1);
      if (i % 64 == 0)
        $display("spi_slave rx_only %0d/256", i);
    end

    n = 0;
    for (int a = 0; a < 16; a++) begin
      for (int b = 240; b < 256; b++) begin
        cov_tx[n] = 8'(a);
        cov_rx[n] = 8'(b);
        n++;
      end
    end
    for (int a = 240; a < 256; a++) begin
      for (int b = 0; b < 16; b++) begin
        cov_tx[n] = 8'(a);
        cov_rx[n] = 8'(b);
        n++;
      end
    end
    if (n != 512)
      $fatal(1, "cross coverage size %0d", n);
    shuffle_pairs(512);

    fork
      run_tx_rx(0);
      run_tx_rx(1);
      run_tx_rx(2);
      run_tx_rx(3);
    join

    for (int id = 0; id < c_N; id++) begin
      if (src_q[id].size() != 0)
        $fatal(1, "extra src beat %s", mode_str(id));
    end

    tb_done = 1'b1;
    $display("PASS spi_slave_tb");
    $finish;
  end
endmodule
