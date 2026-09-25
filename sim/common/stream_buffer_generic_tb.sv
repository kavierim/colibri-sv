// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Generic stream buffer. sim/common/stream_buffer_generic_tb.vhdl default
// g_REGISTER_DATAPATH is false. The registered datapath is exercised too.
module stream_buffer_generic_tb;

  localparam int c_N = 101;
  localparam int c_W = 8;

  for (genvar gi = 0; gi < 2; gi++) begin : gen_mode
    localparam bit c_REG = bit'(gi);

    logic             clk;
    logic             reset;
    logic [c_W-1:0]   snk_data;
    logic             snk_valid;
    logic             snk_ready;
    logic [c_W-1:0]   src_data;
    logic             src_valid;
    logic             src_ready;
    logic [c_W-1:0]   sent [0:c_N-1];
    int               sent_n;
    int               got_n;
    int               stall_left;
    logic             go;
    logic             hold_beat;

    initial begin
      clk = 1'b1;
      forever begin
        #5 clk = 1'b0;
        #5 clk = 1'b1;
      end
    end

    stream_buffer_generic #(
      .data_t(logic [c_W-1:0]),
      .g_REGISTER_DATAPATH(c_REG)
    ) dut (
      .reset_i(reset),
      .clk_i(clk),
      .snk_data_i(snk_data),
      .snk_valid_i(snk_valid),
      .snk_ready_o(snk_ready),
      .src_data_o(src_data),
      .src_ready_i(src_ready),
      .src_valid_o(src_valid)
    );

    initial begin
      reset      = 1'b1;
      snk_valid  = 1'b0;
      snk_data   = '0;
      src_ready  = 1'b0;
      sent_n     = 0;
      got_n      = 0;
      stall_left = 4;
      go         = 1'b0;
      hold_beat  = 1'b0;
      #50;
      @(negedge clk);
      reset = 1'b0;
      @(posedge clk);
      @(negedge clk);
      go = 1'b1;
    end

    always @(negedge clk) begin
      if (reset) begin
        src_ready <= 1'b0;
      end else if (stall_left > 0) begin
        src_ready  <= 1'b0;
        stall_left <= stall_left - 1;
      end else begin
        src_ready <= 1'b1;
        if (($urandom % 2) == 1)
          stall_left <= $urandom_range(1, 8);
      end
    end

    always @(posedge clk) begin
      if (!go)
        hold_beat <= 1'b0;
      else
        hold_beat <= snk_valid && !snk_ready;
    end

    always @(negedge clk) begin
      if (!go) begin
        snk_valid <= 1'b0;
      end else if (hold_beat) begin
      end else if (sent_n < c_N) begin
        if (($urandom % 2) == 0) begin
          logic [c_W-1:0] d;
          d = 8'($urandom_range(16, 127));
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

    always @(posedge clk) begin
      if (!reset && src_valid && src_ready) begin
        if (got_n >= sent_n)
          $fatal(1, "mode %0d: output before the beat was queued", gi);
        if (src_data !== sent[got_n])
          $fatal(1, "mode %0d: mismatch at %0d got %h expected %h",
                 gi, got_n, src_data, sent[got_n]);
        got_n <= got_n + 1;
      end
    end
  end

  initial begin
    wait (gen_mode[0].got_n == c_N && gen_mode[1].got_n == c_N);
    $display("PASS stream_buffer_generic_tb");
    $finish;
  end

  initial begin
    #500us;
    if (gen_mode[0].got_n != c_N || gen_mode[1].got_n != c_N)
      $fatal(1, "timeout got %0d and %0d", gen_mode[0].got_n, gen_mode[1].got_n);
  end

endmodule
