// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Two jtag_serdes instances cross-coupled. Same sequence as jtag_serdes_tb.vhdl:
// 11 random bytes A to B, then 11 B to A. The first beat of each direction is
// the shift pipeline and is not checked. Bytes are in 16..127.
`timescale 1ns/1ps

module jtag_serdes_tb;
  localparam int c_DATA_WIDTH = 8;
  localparam int c_TEST_SIZE = 10;
  localparam time c_CLK_SER_PERIOD = time'(100ns);
  localparam time c_CLK_PAR_PERIOD = time'(1ns);

  logic clk_ser = 1'b1;
  logic clk_par = 1'b1;
  logic reset = 1'b1;
  logic capture = 1'b0;
  logic shift = 1'b0;
  logic update = 1'b0;
  logic clk_ser_g;

  logic [c_DATA_WIDTH-1:0] a_data_i = '0;
  logic a_valid_i = 1'b0;
  logic a_ready_o;
  logic [c_DATA_WIDTH-1:0] a_data_o;
  logic a_valid_o;
  logic [c_DATA_WIDTH-1:0] b_data_i = '0;
  logic b_valid_i = 1'b0;
  logic b_ready_o;
  logic [c_DATA_WIDTH-1:0] b_data_o;
  logic b_valid_o;
  logic ab;
  logic ba;

  logic [7:0] a_q[$];
  logic [7:0] b_q[$];
  bit tb_done = 1'b0;

  // Half periods are literals. Dividing a 1 ns time can truncate to 0.
  always #50ns clk_ser = ~clk_ser;
  always #500ps clk_par = ~clk_par;

  assign clk_ser_g = clk_ser & (capture | shift);

  jtag_serdes #(
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) jtag_serdes_a (
    .clk_ser_i(clk_ser_g),
    .clk_par_i(clk_par),
    .shift_i(shift),
    .update_i(update),
    .par_data_i(a_data_i),
    .par_valid_i(a_valid_i),
    .par_ready_o(a_ready_o),
    .par_data_o(a_data_o),
    .par_valid_o(a_valid_o),
    .ser_data_i(ba),
    .ser_data_o(ab)
  );

  jtag_serdes #(
    .g_DATA_WIDTH(c_DATA_WIDTH)
  ) jtag_serdes_b (
    .clk_ser_i(clk_ser_g),
    .clk_par_i(clk_par),
    .shift_i(shift),
    .update_i(update),
    .par_data_i(b_data_i),
    .par_valid_i(b_valid_i),
    .par_ready_o(b_ready_o),
    .par_data_o(b_data_o),
    .par_valid_o(b_valid_o),
    .ser_data_i(ab),
    .ser_data_o(ba)
  );

  always @(posedge clk_par) begin
    if (a_valid_o)
      a_q.push_back(a_data_o);
    if (b_valid_o)
      b_q.push_back(b_data_o);
  end

  // Capture / shift / update cadence from the VHDL proc_jtag_fsm.
  initial begin
    capture = 1'b0;
    shift   = 1'b0;
    update  = 1'b0;
    wait (reset == 1'b0);
    forever begin
      update  = 1'b0;
      shift   = 1'b0;
      capture = 1'b0;
      repeat (3) @(posedge clk_ser);
      #1ps;
      capture = 1'b1;
      @(posedge clk_par);
      @(posedge clk_ser);
      #1ps;
      capture = 1'b0;
      shift   = 1'b1;
      repeat (8) @(posedge clk_ser);
      #1ps;
      shift  = 1'b0;
      update = 1'b1;
      @(posedge clk_ser);
    end
  end

  initial begin
    #2ms;
    if (!tb_done)
      $fatal(1, "jtag_serdes_tb watchdog");
  end

  task automatic push_side(input bit to_a, input logic [7:0] data);
    int spins;
    if (to_a) begin
      a_data_i  = data;
      a_valid_i = 1'b1;
    end else begin
      b_data_i  = data;
      b_valid_i = 1'b1;
    end
    spins = 0;
    forever begin
      @(posedge clk_par);
      if ((to_a && a_ready_o) || (!to_a && b_ready_o)) begin
        @(negedge clk_par);
        if (to_a)
          a_valid_i = 1'b0;
        else
          b_valid_i = 1'b0;
        return;
      end
      spins++;
      if (spins > 500000)
        $fatal(1, "JTAG push timeout");
    end
  endtask

  task automatic pop_side(input bit from_b, output logic [7:0] data);
    int spins;
    spins = 0;
    if (from_b) begin
      while (b_q.size() == 0) begin
        @(posedge clk_par);
        spins++;
        if (spins > 500000)
          $fatal(1, "JTAG pop B timeout");
      end
      data = b_q.pop_front();
    end else begin
      while (a_q.size() == 0) begin
        @(posedge clk_par);
        spins++;
        if (spins > 500000)
          $fatal(1, "JTAG pop A timeout");
      end
      data = a_q.pop_front();
    end
  endtask

  initial begin
    logic [7:0] prev;
    logic [7:0] data;
    logic [7:0] recv;
    reset     = 1'b1;
    a_valid_i = 1'b0;
    b_valid_i = 1'b0;
    @(posedge clk_par);
    reset = 1'b0;

    a_q = {};
    b_q = {};
    for (int i = 0; i <= c_TEST_SIZE; i++) begin
      data = 8'($urandom_range(127, 16));
      #1ns;
      push_side(1'b1, data);
      pop_side(1'b1, recv);
      if (i != 0) begin
        if (recv !== prev)
          $fatal(1, "A to B mismatch i=%0d got=0x%02h exp=0x%02h", i, recv, prev);
      end
      prev = data;
    end

    a_q = {};
    b_q = {};
    for (int i = 0; i <= c_TEST_SIZE; i++) begin
      data = 8'($urandom_range(127, 16));
      #1ns;
      push_side(1'b0, data);
      pop_side(1'b0, recv);
      if (i != 0) begin
        if (recv !== prev)
          $fatal(1, "B to A mismatch i=%0d got=0x%02h exp=0x%02h", i, recv, prev);
      end
      prev = data;
    end

    tb_done = 1'b1;
    $display("PASS jtag_serdes_tb");
    $finish;
  end
endmodule
