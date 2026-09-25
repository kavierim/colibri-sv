// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// spi_master scenarios from spi_master_tb.vhdl and sim/io/spi/run.py.
// tx_only and rx_only cover bytes 0..255 at CPOL=0 CPHA=0.
// tx_rx covers the cross of (0..15, 240..255) and (240..255, 0..15)
// at all four CPOL/CPHA combinations. Each bin is visited once; order is a
// bounded shuffle. rx_only is not run at CPHA=1 (upstream UVVM limitation).
`timescale 1ns/1ps

module spi_master_tb;
  localparam time c_CLK_PERIOD = time'(25ns);
  localparam int unsigned c_SCK_FREQ = 1_000_000;
  localparam int c_WORD = 8;
  localparam int c_N = 4;
  // run.py: product(phase, polarity) over {0,1} x {0,1}
  localparam bit c_CPHA[4] = '{1'b0, 1'b0, 1'b1, 1'b1};
  localparam bit c_CPOL[4] = '{1'b0, 1'b1, 1'b0, 1'b1};

  logic clk = 1'b0;
  logic miso[4];
  logic mosi[4];
  logic cs_n[4];
  logic sck[4];
  logic [c_WORD-1:0] src_data[4];
  logic src_valid[4];
  logic [c_WORD-1:0] snk_data[4];
  logic snk_valid[4];
  logic snk_ready[4];
  logic [7:0] src_q[4][$];
  logic [7:0] cov_byte[256];
  logic [7:0] cov_tx[512];
  logic [7:0] cov_rx[512];
  logic       slv_go[4];
  logic       slv_done[4];
  logic [7:0] slv_tx[4];
  logic [7:0] slv_rx[4];
  bit tb_done = 1'b0;

  always #(c_CLK_PERIOD / 2) clk = ~clk;

  for (genvar gi = 0; gi < c_N; gi++) begin : gen_master
    localparam bit c_POL = c_CPOL[gi];
    localparam bit c_PHA = c_CPHA[gi];
    spi_master #(
      .g_CLOCK_PERIOD(c_CLK_PERIOD),
      .g_SCK_FREQUENCY(c_SCK_FREQ),
      .g_WORD_SIZE(c_WORD),
      .g_SCK_POLARITY(c_POL),
      .g_SCK_PHASE(c_PHA)
    ) dut (
      .clk_i(clk),
      .miso_i(miso[gi]),
      .mosi_o(mosi[gi]),
      .cs_n_o(cs_n[gi]),
      .sck_o(sck[gi]),
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
      $fatal(1, "spi_master_tb watchdog");
  end

  function automatic string mode_str(input int id);
    return $sformatf("CPOL=%0d CPHA=%0d", c_CPOL[id], c_CPHA[id]);
  endfunction

  task automatic wait_sck(input int id, input bit rise);
    logic prev;
    int spins;
    prev  = sck[id];
    spins = 0;
    forever begin
      @(posedge clk);
      if (rise && !prev && sck[id])
        return;
      if (!rise && prev && !sck[id])
        return;
      prev = sck[id];
      spins++;
      if (spins > 8000)
        $fatal(1, "SCK timeout %s", mode_str(id));
    end
  endtask

  // SPI slave BFM on the master pins. Samples MOSI and drives MISO.
  task automatic tb_spi_slave(
    input int id,
    input logic [7:0] tx,
    output logic [7:0] rx
  );
    bit sample_rise;
    int spins;
    sample_rise = (c_CPOL[id] == c_CPHA[id]);
    rx = '0;
    spins = 0;
    while (cs_n[id] !== 1'b0) begin
      @(posedge clk);
      spins++;
      if (spins > 20000)
        $fatal(1, "CS assert timeout %s", mode_str(id));
    end
    miso[id] = tx[7];
    for (int i = 0; i < 8; i++) begin
      wait_sck(id, sample_rise);
      rx = {rx[6:0], mosi[id]};
      if (i != 7) begin
        wait_sck(id, !sample_rise);
        miso[id] = tx[6-i];
      end
    end
    spins = 0;
    while (cs_n[id] !== 1'b1) begin
      @(posedge clk);
      spins++;
      if (spins > 20000)
        $fatal(1, "CS release timeout %s", mode_str(id));
    end
  endtask

  // One process per master. Re-arming a fork each byte faults in Verilator.
  for (genvar gs = 0; gs < c_N; gs++) begin : gen_slv_srv
    initial begin
      logic [7:0] rx;
      slv_go[gs]   = 1'b0;
      slv_done[gs] = 1'b0;
      forever begin
        wait (slv_go[gs] === 1'b1);
        tb_spi_slave(gs, slv_tx[gs], rx);
        slv_rx[gs]   = rx;
        slv_done[gs] = 1'b1;
        wait (slv_go[gs] === 1'b0);
        slv_done[gs] = 1'b0;
      end
    end
  end

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
      if (spins > 8000)
        $fatal(1, "src timeout %s", mode_str(id));
    end
    data = src_q[id].pop_front();
  endtask

  task automatic xfer(
    input int id,
    input logic [7:0] to_mosi,
    input logic [7:0] to_miso,
    input bit check_mosi,
    input bit check_miso
  );
    logic [7:0] got_mosi;
    logic [7:0] got_miso;
    // A fork inside this loop crashes Verilator 5.020 on the second call.
    // The slave BFM runs in its own process and is armed with slv_go.
    slv_tx[id] = to_miso;
    slv_go[id]  = 1'b1;
    send_snk(id, to_mosi);
    while (slv_done[id] !== 1'b1)
      @(posedge clk);
    got_mosi   = slv_rx[id];
    slv_go[id] = 1'b0;
    while (slv_done[id] !== 1'b0)
      @(posedge clk);
    pop_src(id, got_miso);
    if (check_mosi && got_mosi !== to_mosi)
      $fatal(1, "MOSI %s got=0x%02h exp=0x%02h", mode_str(id), got_mosi, to_mosi);
    if (check_miso && got_miso !== to_miso)
      $fatal(1, "MISO %s got=0x%02h exp=0x%02h", mode_str(id), got_miso, to_miso);
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

  task automatic run_tx_rx(input int id);
    for (int i = 0; i < 512; i++) begin
      xfer(id, cov_tx[i], cov_rx[i], 1'b1, 1'b1);
      if (i % 128 == 0)
        $display("spi_master tx_rx %s %0d/512", mode_str(id), i);
    end
    $display("spi_master tx_rx %s done", mode_str(id));
  endtask

  initial begin
    int n;
    for (int i = 0; i < c_N; i++) begin
      miso[i] = 1'b0;
      snk_data[i] = '0;
      snk_valid[i] = 1'b0;
    end
    repeat (8) @(posedge clk);

    for (int i = 0; i < 256; i++)
      cov_byte[i] = 8'(i);
    shuffle_bytes(256);
    $display("spi_master tx_only");
    for (int i = 0; i < 256; i++) begin
      xfer(0, cov_byte[i], cov_byte[i], 1'b0, 1'b1);
      if (i % 64 == 0)
        $display("spi_master tx_only %0d/256", i);
    end

    $display("spi_master rx_only");
    for (int i = 0; i < 256; i++) begin
      xfer(0, cov_byte[i], 8'h00, 1'b1, 1'b0);
      if (i % 64 == 0)
        $display("spi_master rx_only %0d/256", i);
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
    $display("PASS spi_master_tb");
    $finish;
  end
endmodule
