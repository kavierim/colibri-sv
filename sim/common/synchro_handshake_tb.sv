// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Handshake CDC. sim/common/synchro_handshake_tb.vhdl: 11 random 4-bit
// words, 5 ns sink clock, 17 ns source clock, 50% stalls of 1..8 cycles.
module synchro_handshake_tb;

  localparam int  c_W    = 4;
  localparam int  c_N    = 11;
  localparam time c_SNK  = 5ns;
  localparam time c_SRC  = 17ns;

  logic           snk_clk;
  logic           src_clk;
  logic           reset;
  logic [c_W-1:0] snk_data;
  logic           snk_valid;
  logic           snk_ready;
  logic [c_W-1:0] src_data;
  logic           src_valid;
  logic           src_ready;

  logic [c_W-1:0] sent [0:c_N-1];
  int             sent_n;
  int             got_n;
  int             src_stall;
  logic           go;
  logic           hold_beat;

  synchro_handshake #(
    .g_DATA_WIDTH(c_W)
  ) dut (
    .snk_clk_i(snk_clk),
    .src_clk_i(src_clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  initial begin
    snk_clk = 1'b1;
    forever begin
      #(c_SNK / 2) snk_clk = ~snk_clk;
    end
  end

  initial begin
    src_clk = 1'b1;
    forever begin
      #(c_SRC / 2) src_clk = ~src_clk;
    end
  end

  initial begin
    reset     = 1'b1;
    snk_valid = 1'b0;
    snk_data  = '0;
    src_ready = 1'b0;
    sent_n    = 0;
    got_n     = 0;
    src_stall = 0;
    go        = 1'b0;
    hold_beat = 1'b0;
    #(c_SRC * 3);
    reset = 1'b0;
    #(c_SRC);
    @(negedge snk_clk);
    go = 1'b1;
  end

  always @(negedge src_clk) begin
    if (reset) begin
      src_ready <= 1'b0;
      src_stall <= 0;
    end else if (src_stall > 0) begin
      src_ready <= 1'b0;
      src_stall <= src_stall - 1;
    end else begin
      src_ready <= 1'b1;
      if (($urandom % 2) == 1)
        src_stall <= $urandom_range(1, 8);
    end
  end

  always @(posedge snk_clk) begin
    if (!go)
      hold_beat <= 1'b0;
    else
      hold_beat <= snk_valid && !snk_ready && !reset;
  end

  always @(negedge snk_clk) begin
    if (!go) begin
      snk_valid <= 1'b0;
    end else if (hold_beat) begin
      // Hold the beat until the clock after it is accepted.
    end else if (sent_n < c_N) begin
      if (($urandom % 2) == 0) begin
        logic [c_W-1:0] d;
        d = c_W'($urandom_range(0, (1 << c_W) - 1));
        snk_data  <= d;
        snk_valid <= 1'b1;
        sent[sent_n] = d;
        sent_n = sent_n + 1;
      end else begin
        snk_valid <= 1'b0;
      end
    end else begin
      snk_valid <= 1'b0;
    end
  end

  always @(posedge src_clk) begin
    if (!reset && src_valid && src_ready) begin
      if (got_n >= sent_n)
        $fatal(1, "received a beat before it was sent");
      if (src_data !== sent[got_n])
        $fatal(1, "data mismatch at %0d: got %h expected %h", got_n, src_data, sent[got_n]);
      got_n <= got_n + 1;
    end
  end

  initial begin
    wait (got_n == c_N);
    $display("PASS synchro_handshake_tb");
    $finish;
  end

  initial begin
    #500us;
    if (got_n != c_N)
      $fatal(1, "timeout after %0d of %0d words", got_n, c_N);
  end

endmodule
