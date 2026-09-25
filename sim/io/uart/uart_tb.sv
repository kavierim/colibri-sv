// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// UART loopback. Same stimulus as sim/io/uart/uart_tb.vhdl: 11 bytes, 0x0A+i.
`timescale 1ns/1ps

module uart_tb;
  localparam time c_CLK_PERIOD = time'(25ns);
  localparam int unsigned c_BAUD_RATE = 1_000_000;
  localparam int c_N_BYTES = 11;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [7:0] tx_data = '0;
  logic tx_valid = 1'b0;
  logic tx_ready;
  logic [7:0] rx_data;
  logic rx_valid;
  logic tx_pin;
  logic rx_pin;
  logic [7:0] rx_q[$];
  bit tb_done = 1'b0;

  always #(c_CLK_PERIOD / 2) clk = ~clk;

  assign rx_pin = tx_pin;

  uart #(
    .g_CLOCK_PERIOD(c_CLK_PERIOD),
    .g_BAUD_RATE(c_BAUD_RATE)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .tx_data_i(tx_data),
    .tx_valid_i(tx_valid),
    .tx_ready_o(tx_ready),
    .rx_data_o(rx_data),
    .rx_valid_o(rx_valid),
    .rx_pin_i(rx_pin),
    .tx_pin_o(tx_pin)
  );

  always @(posedge clk) begin
    if (rx_valid)
      rx_q.push_back(rx_data);
  end

  initial begin
    #2ms;
    if (!tb_done)
      $fatal(1, "uart_tb watchdog");
  end

  task automatic send_byte(input logic [7:0] data);
    int spins;
    @(negedge clk);
    tx_data  = data;
    tx_valid = 1'b1;
    spins = 0;
    forever begin
      @(posedge clk);
      if (tx_ready) begin
        @(negedge clk);
        tx_valid = 1'b0;
        return;
      end
      spins++;
      if (spins > 20000)
        $fatal(1, "UART TX ready timeout");
    end
  endtask

  task automatic pop_byte(output logic [7:0] data);
    int spins;
    spins = 0;
    while (rx_q.size() == 0) begin
      @(posedge clk);
      spins++;
      if (spins > 40000)
        $fatal(1, "UART RX timeout");
    end
    data = rx_q.pop_front();
  endtask

  initial begin
    logic [7:0] got;
    reset = 1'b1;
    #(c_CLK_PERIOD);
    reset = 1'b0;
    repeat (4) @(posedge clk);

    for (int i = 0; i < c_N_BYTES; i++) begin
      logic [7:0] sendb;
      sendb = 8'h0A + 8'(i);
      send_byte(sendb);
      pop_byte(got);
      if (got !== sendb)
        $fatal(1, "UART mismatch i=%0d got=0x%02h exp=0x%02h", i, got, sendb);
    end

    repeat (40) @(posedge clk);
    if (rx_q.size() != 0)
      $fatal(1, "UART extra RX byte");

    tb_done = 1'b1;
    $display("PASS uart_tb");
    $finish;
  end
endmodule
