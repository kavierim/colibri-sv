// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from prbs_tb.vhdl: PRBS-7 scrambler/descrambler with random valid and ready.

`timescale 1ns/1ps

module prbs_tb;

  localparam int c_DATA_WIDTH = 32;
  localparam logic [c_DATA_WIDTH-1:0] c_SIGNATURE = 32'hdeadbeef;

  logic                      clk = 1'b1;
  logic                      reset = 1'b1;
  logic [c_DATA_WIDTH-1:0]   snk_data = '0;
  logic [c_DATA_WIDTH-1:0]   src_data;
  logic [c_DATA_WIDTH-1:0]   scrambled_data;
  logic                      valid_sig;
  logic                      snk_valid = 1'b0;
  logic                      src_valid;
  logic                      ready_sig;
  logic                      src_ready = 1'b0;
  int                        n_checked = 0;

  always #5 clk = ~clk;

  scrambler #(
    .g_DATA_WIDTH(c_DATA_WIDTH),
    .g_SCRAMBLER_POLY(colibri_poly::c_PRBS_7),
    .g_INIT_VAL(8'ha4)
  ) scrambler_inst (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(),
    .src_data_o(scrambled_data),
    .src_valid_o(valid_sig),
    .src_ready_i(ready_sig)
  );

  descrambler #(
    .g_DATA_WIDTH(c_DATA_WIDTH),
    .g_SCRAMBLER_POLY(colibri_poly::c_PRBS_7),
    .g_INIT_VAL(8'ha4)
  ) descrambler_inst (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(scrambled_data),
    .snk_valid_i(valid_sig),
    .snk_ready_o(ready_sig),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  always @(posedge clk) begin
    snk_valid <= 1'($urandom_range(0, 1));
    src_ready <= 1'($urandom_range(0, 1));
    if (!reset && src_valid) begin
      n_checked <= n_checked + 1;
      if (src_data != c_SIGNATURE)
        $fatal(1, "prbs_tb: signature mismatch got %h", src_data);
    end
  end

  initial begin
    @(posedge clk);
    reset    = 1'b0;
    snk_data = c_SIGNATURE;
    repeat (100) @(posedge clk);
    if (n_checked == 0)
      $fatal(1, "prbs_tb: no valid descrambled words");
    $display("PASS prbs_tb");
    $finish;
  end

  initial begin
    #10us;
    $fatal(1, "timeout prbs_tb");
  end

endmodule
