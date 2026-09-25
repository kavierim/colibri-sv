// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-check for be_remove_trail. Twenty-one packets of 30 down to 10 bytes
// lose their last three bytes. snk_sop_i stays 1 outside a multi-word packet.

`timescale 1ns/1ps

module be_remove_trail_tb;

  // verilator lint_off REALCVT
  localparam time c_CLK_PERIOD = 25ns;
  // verilator lint_on REALCVT
  localparam int c_DATA_WIDTH  = 32;
  localparam int c_N_PACKETS   = 20;
  localparam int c_MIN_SIZE    = 10;
  localparam int c_MAX_LEN     = c_MIN_SIZE + c_N_PACKETS;
  localparam logic [31:0] c_HEADER = 32'hBADC0FFE;
  localparam logic [7:0] c_HDR0 = 8'hBA;
  localparam logic [7:0] c_HDR1 = 8'hDC;
  localparam logic [7:0] c_HDR2 = 8'h0F;

  logic clk   = 1'b0;
  logic reset = 1'b1;
  logic [2:0] shl;
  logic snk_ready;
  logic snk_valid = 1'b0;
  logic snk_sop   = 1'b1;
  logic snk_eop   = 1'b0;
  logic [1:0] snk_empty = '0;
  logic [c_DATA_WIDTH-1:0] snk_data = '0;
  logic [c_DATA_WIDTH-1:0] src_tail;
  logic src_ready = 1'b1;
  logic src_valid;
  logic src_sop;
  logic src_eop;
  logic [1:0] src_empty;
  logic [c_DATA_WIDTH-1:0] src_data;

  logic [7:0] cap[0:127];
  int cap_n = 0;
  int pkts  = 0;

  assign shl = 3'd3;
  be_remove_trail #(
    .g_DATA_WIDTH  (c_DATA_WIDTH),
    .g_REGISTER_OUT(1'b0)
  ) dut (
    .clk_i      (clk),
    .reset_i    (reset),
    .shl_i      (shl),
    .snk_ready_o(snk_ready),
    .snk_valid_i(snk_valid),
    .snk_sop_i  (snk_sop),
    .snk_eop_i  (snk_eop),
    .snk_empty_i(snk_empty),
    .snk_data_i (snk_data),
    .src_ready_i(src_ready),
    .src_valid_o(src_valid),
    .src_sop_o  (src_sop),
    .src_eop_o  (src_eop),
    .src_empty_o(src_empty),
    .src_data_o (src_data),
    .src_tail_o (src_tail)
  );

  always #(c_CLK_PERIOD / 2) clk = ~clk;

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
      if (src_eop)
        pkts = pkts + 1;
    end
  end

  task automatic send_pkt(input int n, input logic [7:0] bytes[0:63]);
    int nwords;
    int vb;
    logic [31:0] word;
    nwords = (n + 3) / 4;
    for (int w = 0; w < nwords; w++) begin
      vb   = ((n - w * 4) > 4) ? 4 : (n - w * 4);
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

  task automatic expect_pkt(
    input int seen,
    input int base,
    input int nexp,
    input logic [7:0] exp[0:63]
  );
    int guard;
    guard = 0;
    while (pkts == seen) begin
      @(posedge clk);
      guard++;
      if (guard > 400)
        $fatal(1, "timeout waiting for packet");
    end
    @(posedge clk);
    if ((cap_n - base) != nexp)
      $fatal(1, "length exp %0d got %0d", nexp, cap_n - base);
    for (int i = 0; i < nexp; i++) begin
      if (cap[base + i] !== exp[i])
        $fatal(1, "byte %0d exp %02x got %02x", i, exp[i], cap[base + i]);
    end
  endtask

  initial begin : proc_sequencer
    logic [7:0] payload[0:63];
    logic [7:0] expect_b[0:63];
    int nbytes;
    int nexp;
    int seen;
    int base;

    repeat (5) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (4) @(posedge clk);

    for (int i = 0; i <= c_N_PACKETS; i++) begin
      nbytes = c_MAX_LEN - i;
      nexp   = nbytes - 3;
      for (int b = 0; b < nbytes; b++)
        payload[b] = 8'(c_MAX_LEN - 1 - b);
      for (int b = 0; b < nexp; b++)
        expect_b[b] = payload[b];

      seen = pkts;
      base = cap_n;
      send_pkt(nbytes, payload);
      expect_pkt(seen, base, nexp, expect_b);
      repeat (10) @(posedge clk);
    end

    $display("PASS be_remove_trail_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #2ms;
    $fatal(1, "be_remove_trail_tb watchdog");
  end

endmodule
