// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// arbiter_coverage: random requests, held for 1..6 cycles. Stop once each of
// "no request", "one request", and "more than one request" has been seen twice.
// Grants are one-hot, and a grant is present only for a live request.

`timescale 1ns/1ps

module arbiter_tb;
  localparam int c_NUM_INPUTS = 4;
  localparam int c_MAX_HOLD   = 5;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [c_NUM_INPUTS-1:0] requests = '0;
  logic [c_NUM_INPUTS-1:0] grants;

  int cov_none;
  int cov_one;
  int cov_many;

  always #5 clk = ~clk;

  arbiter #(
    .g_NUM_INPUTS (c_NUM_INPUTS)
  ) u_dut (
    .clk_i      (clk),
    .reset_i    (reset),
    .requests_i (requests),
    .grants_o   (grants)
  );

  function automatic int count_ones(input logic [c_NUM_INPUTS-1:0] vec);
    int n;
    int i;
    n = 0;
    for (i = 0; i < c_NUM_INPUTS; i++)
      if (vec[i])
        n++;
    return n;
  endfunction

  initial begin
    int hold;
    int k;
    int ones;
    cov_none = 0;
    cov_one  = 0;
    cov_many = 0;
    void'($urandom(32'hA4B1_0001));
    @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    while (cov_none < 2 || cov_one < 2 || cov_many < 2) begin
      requests = c_NUM_INPUTS'($urandom_range((1 << c_NUM_INPUTS) - 1, 0));
      hold = $urandom_range(c_MAX_HOLD, 0);
      for (k = 0; k <= hold; k++) begin
        @(posedge clk);
        if (!reset) begin
          ones = count_ones(grants);
          if (ones > 1)
            $fatal(1, "grants should only contain a single high bit");
          if (|requests && !(|(requests & grants)))
            $fatal(1, "no grants when a request is present");
          ones = count_ones(requests);
          if (ones == 0)
            cov_none++;
          else if (ones == 1)
            cov_one++;
          else
            cov_many++;
        end
      end
    end
    repeat (2) @(posedge clk);
    $display("PASS arbiter_tb");
    $finish;
  end

  initial begin
    reset = 1'b1;
  end

  initial begin
    #20us;
    $fatal(1, "arbiter_tb watchdog");
  end
endmodule
