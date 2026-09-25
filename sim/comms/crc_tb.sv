// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenarios from crc_tb.vhdl and run.py: invert sweep on CRC-32, and data widths
// 16/32/64 with CRC-8, CRC-16-CCITT, and CRC-32. XOR-out is all ones.
// Each packet length from 1 to g_PACKET_SIZE is sent g_N_PACKETS times.

`timescale 1ns/1ps

module crc_case #(
  parameter int g_DATA_WIDTH = 32,
  parameter g_CRC_POLY = 32'h04c11db7,
  parameter bit g_INVERT_IN = 1'b1,
  parameter bit g_INVERT_OUT = 1'b1,
  parameter int g_N_PACKETS = 5,
  parameter int g_PACKET_SIZE = 50
) (
  output logic done
);

  localparam int c_CRC_W = $bits(g_CRC_POLY);
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(g_DATA_WIDTH, 8);
  localparam int c_NBYTES = g_DATA_WIDTH / 8;
  localparam int c_MAX_WORDS = g_PACKET_SIZE;

  logic                        clk = 1'b1;
  logic                        reset = 1'b1;
  logic [g_DATA_WIDTH-1:0]     snk_data = '0;
  logic                        snk_sop = 1'b0;
  logic                        snk_eop = 1'b0;
  logic [c_EMPTY_W-1:0]        snk_empty = '0;
  logic                        snk_valid = 1'b0;
  logic                        snk_ready;
  logic [g_DATA_WIDTH-1:0]     src_data;
  logic                        src_sop;
  logic                        src_eop;
  logic [c_EMPTY_W-1:0]        src_empty;
  logic                        src_valid;
  logic                        src_ready = 1'b0;
  logic [c_CRC_W-1:0]          src_crc;
  logic [g_DATA_WIDTH-1:0]     exp_data [0:c_MAX_WORDS-1];
  logic                        exp_sop [0:c_MAX_WORDS-1];
  logic                        exp_eop [0:c_MAX_WORDS-1];
  logic [c_EMPTY_W-1:0]        exp_empty [0:c_MAX_WORDS-1];
  logic [c_CRC_W-1:0]          exp_crc;
  int                          exp_n = 0;
  int                          got_n = 0;
  int                          src_stall = 0;
  logic                        armed = 1'b0;
  logic                        packet_done = 1'b0;

  always #2.5 clk = ~clk;

  crc #(
    .g_DATA_WIDTH(g_DATA_WIDTH),
    .g_CRC_POLY(g_CRC_POLY),
    .g_INIT_VAL({c_CRC_W{1'b0}}),
    .g_XOR_OUT({c_CRC_W{1'b1}}),
    .g_INVERT_IN(g_INVERT_IN),
    .g_INVERT_OUT(g_INVERT_OUT)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_empty_i(snk_empty),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_data_o(src_data),
    .src_sop_o(src_sop),
    .src_eop_o(src_eop),
    .src_empty_o(src_empty),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready),
    .src_crc_o(src_crc)
  );

  always @(posedge clk) begin
    if (reset) begin
      src_ready <= 1'b0;
      src_stall <= 0;
    end else begin
      if (armed && src_valid && src_ready) begin
        if (got_n >= exp_n)
          $fatal(1, "crc w=%0d poly=%h: extra output word", g_DATA_WIDTH, g_CRC_POLY);
        if (src_data != exp_data[got_n])
          $fatal(1, "crc w=%0d poly=%h inv=%0d/%0d: data mismatch word %0d got %h exp %h",
                 g_DATA_WIDTH, g_CRC_POLY, g_INVERT_IN, g_INVERT_OUT,
                 got_n, src_data, exp_data[got_n]);
        if (src_sop != exp_sop[got_n])
          $fatal(1, "crc w=%0d: sop mismatch at word %0d", g_DATA_WIDTH, got_n);
        if (src_eop != exp_eop[got_n])
          $fatal(1, "crc w=%0d: eop mismatch at word %0d", g_DATA_WIDTH, got_n);
        if (src_empty != exp_empty[got_n])
          $fatal(1, "crc w=%0d: empty mismatch at word %0d got %0d exp %0d",
                 g_DATA_WIDTH, got_n, src_empty, exp_empty[got_n]);
        if (src_eop) begin
          if (src_crc != exp_crc)
            $fatal(1, "crc w=%0d poly=%h inv=%0d/%0d: crc mismatch got %h exp %h",
                   g_DATA_WIDTH, g_CRC_POLY, g_INVERT_IN, g_INVERT_OUT, src_crc, exp_crc);
          packet_done <= 1'b1;
        end
        got_n <= got_n + 1;
      end
      if (src_stall > 0) begin
        src_ready <= 1'b0;
        src_stall <= src_stall - 1;
      end else begin
        src_ready <= 1'b1;
        if (armed && src_valid && src_ready && ($urandom_range(0, 1) == 1))
          src_stall <= $urandom_range(0, 5);
      end
    end
  end

  function automatic logic [7:0] invert_byte(input logic [7:0] word);
    logic [7:0] v_res;
    for (int i = 0; i < 8; i++)
      v_res[i] = word[7 - i];
    return v_res;
  endfunction

  function automatic logic [c_CRC_W-1:0] invert_crc(input logic [c_CRC_W-1:0] word);
    logic [c_CRC_W-1:0] v_res;
    for (int i = 0; i < c_CRC_W; i++)
      v_res[i] = word[c_CRC_W - 1 - i];
    return v_res;
  endfunction

  task automatic send_packet(input int size);
    logic [7:0] msg [0:g_PACKET_SIZE-1];
    logic [c_CRC_W-1:0] crc_v;
    int rem;
    int empty;
    int nwords;
    int guard;
    for (int i = 0; i < size; i++)
      msg[i] = 8'($urandom_range(0, 255));
    crc_v = '0;
    for (int i = 0; i < size; i++) begin
      logic [7:0] b;
      b = g_INVERT_IN ? invert_byte(msg[i]) : msg[i];
      for (int bitn = 7; bitn >= 0; bitn--) begin
        logic fb;
        fb    = crc_v[c_CRC_W-1] ^ b[bitn];
        crc_v = {crc_v[c_CRC_W-2:0], 1'b0};
        if (fb)
          crc_v = crc_v ^ g_CRC_POLY;
      end
    end
    if (g_INVERT_OUT)
      crc_v = invert_crc(crc_v);
    crc_v = crc_v ^ {c_CRC_W{1'b1}};
    rem = size % c_NBYTES;
    empty = (rem == 0) ? 0 : (c_NBYTES - rem);
    nwords = (size + c_NBYTES - 1) / c_NBYTES;
    for (int w = 0; w < nwords; w++) begin
      logic [g_DATA_WIDTH-1:0] word;
      word = '0;
      for (int b = 0; b < c_NBYTES; b++) begin
        int mi;
        mi = w * c_NBYTES + b;
        if (mi < size)
          word[g_DATA_WIDTH-1-b*8 -: 8] = msg[mi];
      end
      exp_data[w]  = word;
      exp_sop[w]   = (w == 0);
      exp_eop[w]   = (w == nwords - 1);
      exp_empty[w] = (w == nwords - 1) ? c_EMPTY_W'(empty) : '0;
    end
    exp_crc      = crc_v;
    exp_n        = nwords;
    got_n        = 0;
    packet_done  = 1'b0;
    armed        = 1'b1;
    for (int w = 0; w < nwords; w++) begin
      @(negedge clk);
      if ($urandom_range(0, 1) == 1) begin
        snk_valid = 1'b0;
        repeat ($urandom_range(0, 5)) @(posedge clk);
        @(negedge clk);
      end
      snk_data  = exp_data[w];
      snk_sop   = exp_sop[w];
      snk_eop   = exp_eop[w];
      snk_empty = exp_empty[w];
      snk_valid = 1'b1;
      guard = 0;
      @(posedge clk);
      while (!(snk_valid && snk_ready)) begin
        @(posedge clk);
        guard++;
        if (guard > 100000)
          $fatal(1, "crc w=%0d: sink ready timeout", g_DATA_WIDTH);
      end
    end
    @(negedge clk);
    snk_valid = 1'b0;
    guard = 0;
    while (!packet_done) begin
      @(posedge clk);
      guard++;
      if (guard > 100000)
        $fatal(1, "crc w=%0d poly=%h: packet timeout size %0d", g_DATA_WIDTH, g_CRC_POLY, size);
    end
    armed = 1'b0;
    @(negedge clk);
    snk_valid = 1'b0;
    repeat (2) @(posedge clk);
  endtask

  initial begin
    done = 1'b0;
    repeat (4) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (2) @(posedge clk);
    for (int rep = 0; rep < g_N_PACKETS; rep++) begin
      for (int size = 1; size <= g_PACKET_SIZE; size++)
        send_packet(size);
    end
    done = 1'b1;
  end

endmodule

module crc_tb;

  logic done [0:11];

  crc_case #(.g_DATA_WIDTH(32), .g_CRC_POLY(32'h04c11db7), .g_INVERT_IN(1'b0), .g_INVERT_OUT(1'b0)) u00 (.done(done[0]));
  crc_case #(.g_DATA_WIDTH(32), .g_CRC_POLY(32'h04c11db7), .g_INVERT_IN(1'b0), .g_INVERT_OUT(1'b1)) u01 (.done(done[1]));
  crc_case #(.g_DATA_WIDTH(32), .g_CRC_POLY(32'h04c11db7), .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b0)) u10 (.done(done[2]));
  crc_case #(.g_DATA_WIDTH(32), .g_CRC_POLY(32'h04c11db7), .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u11 (.done(done[3]));
  crc_case #(.g_DATA_WIDTH(16), .g_CRC_POLY(8'h07),       .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u16_8 (.done(done[4]));
  crc_case #(.g_DATA_WIDTH(16), .g_CRC_POLY(16'h1021),    .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u16_16 (.done(done[5]));
  crc_case #(.g_DATA_WIDTH(16), .g_CRC_POLY(32'h04c11db7),.g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u16_32 (.done(done[6]));
  crc_case #(.g_DATA_WIDTH(32), .g_CRC_POLY(8'h07),       .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u32_8 (.done(done[7]));
  crc_case #(.g_DATA_WIDTH(32), .g_CRC_POLY(16'h1021),    .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u32_16 (.done(done[8]));
  crc_case #(.g_DATA_WIDTH(64), .g_CRC_POLY(8'h07),       .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u64_8 (.done(done[9]));
  crc_case #(.g_DATA_WIDTH(64), .g_CRC_POLY(16'h1021),    .g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u64_16 (.done(done[10]));
  crc_case #(.g_DATA_WIDTH(64), .g_CRC_POLY(32'h04c11db7),.g_INVERT_IN(1'b1), .g_INVERT_OUT(1'b1)) u64_32 (.done(done[11]));

  initial begin
    int n;
    n = 0;
    while (n != 12) begin
      #1000;
      n = 0;
      for (int i = 0; i < 12; i++)
        if (done[i])
          n++;
    end
    $display("PASS crc_tb");
    $finish;
  end

  initial begin
    #50ms;
    $fatal(1, "timeout crc_tb");
  end

endmodule
