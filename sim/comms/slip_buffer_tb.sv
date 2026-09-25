// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenarios from slip_buffer_tb.vhdl: passthrough, then random slip.
// Both sides stall with probability 1/2 for 1 to 8 cycles.

`timescale 1ns/1ps

module slip_buffer_tb;

  localparam int c_W = 8;
  localparam int c_TEST = 100 * c_W;
  localparam int c_NCHECK = (c_TEST / c_W) - 1;

  logic              clk = 1'b1;
  logic              reset = 1'b1;
  logic              slip = 1'b0;
  logic [c_W-1:0]    snk_data = '0;
  logic              snk_valid = 1'b0;
  logic              snk_ready;
  logic              src_valid;
  logic              src_ready = 1'b0;
  logic [c_W-1:0]    src_data;
  logic [c_TEST-1:0] test_vec;
  logic              slip_en = 1'b0;
  logic              checking = 1'b0;
  int                slip_cnt = 0;
  int                n_checked = 0;
  int                src_stall = 0;

  always #2.5 clk = ~clk;

  slip_buffer #(
    .g_DATA_WIDTH(c_W)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .slip_i(slip),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready),
    .src_data_o(src_data)
  );

  always @(posedge clk) begin
    if (reset) begin
      src_ready <= 1'b0;
      src_stall <= 0;
      slip_cnt  <= 0;
    end else begin
      if (slip_en && slip) begin
        if (slip_cnt == c_W - 1)
          slip_cnt <= 0;
        else
          slip_cnt <= slip_cnt + 1;
      end
      // Score the beat on the cycle ready is still high, including the first
      // cycle of a stall. Ready falls on the following edges.
      if (src_valid && src_ready && checking && (n_checked < c_NCHECK)) begin
        logic [c_TEST+c_W-1:0] padded;
        int                    v_ptr;
        int                    hi;
        logic [c_W-1:0]        exp;
        padded = {{c_W{1'b0}}, test_vec};
        v_ptr  = (n_checked + 1) * c_W;
        hi     = (c_TEST + c_W - 1) - v_ptr + slip_cnt;
        exp    = padded[hi -: c_W];
        if (src_data != exp)
          $fatal(1, "slip_buffer: data mismatch got %h exp %h slip %0d word %0d",
                 src_data, exp, slip_cnt, n_checked);
        n_checked <= n_checked + 1;
      end
      if (src_stall > 0) begin
        src_ready <= 1'b0;
        src_stall <= src_stall - 1;
      end else begin
        src_ready <= 1'b1;
        if (src_valid && src_ready && checking && ($urandom_range(0, 1) == 1))
          src_stall <= $urandom_range(1, 8);
      end
    end
  end

  task automatic send_word(input logic [c_W-1:0] word);
    int guard;
    @(negedge clk);
    if ($urandom_range(0, 1) == 1)
      repeat ($urandom_range(1, 8)) @(posedge clk);
    @(negedge clk);
    snk_data  = word;
    snk_valid = 1'b1;
    guard = 0;
    @(posedge clk);
    while (!snk_ready) begin
      @(posedge clk);
      guard++;
      if (guard > 100000)
        $fatal(1, "slip_buffer: sink ready timeout");
    end
    @(negedge clk);
    snk_valid = 1'b0;
  endtask

  task automatic run_phase(input bit with_slip);
    n_checked = 0;
    slip      = 1'b0;
    slip_en   = 1'b0;
    snk_valid = 1'b0;
    checking  = 1'b0;
    reset     = 1'b1;
    repeat (4) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    repeat (2) @(posedge clk);
    checking = 1'b1;
    slip_en  = with_slip;
    for (int p = 0; p < c_TEST; p += c_W)
      send_word(test_vec[c_TEST-1-p -: c_W]);
    begin
      int guard;
      guard = 0;
      while (n_checked < c_NCHECK) begin
        @(posedge clk);
        guard++;
        if (guard > 200000)
          $fatal(1, "slip_buffer: read timeout slip=%0d checked=%0d", with_slip, n_checked);
      end
    end
    checking = 1'b0;
    slip_en  = 1'b0;
    slip     = 1'b0;
  endtask

  initial begin
    for (int i = 0; i < c_TEST; i += 8)
      test_vec[c_TEST-1-i -: 8] = 8'($urandom_range(0, 255));
    run_phase(1'b0);
    run_phase(1'b1);
    $display("PASS slip_buffer_tb");
    $finish;
  end

  always @(posedge clk) begin
    if (!reset && slip_en)
      slip <= 1'($urandom_range(0, 1));
    else if (!slip_en)
      slip <= 1'b0;
  end

  initial begin
    #5ms;
    $fatal(1, "timeout slip_buffer_tb");
  end

endmodule
