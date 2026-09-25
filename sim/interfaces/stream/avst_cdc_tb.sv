// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Avalon-ST clock-domain crossing. Random 16-bit words until 16 coverage bins
// of the data range have each been received once. Order is checked.
module avst_cdc_tb;
  localparam int c_DATA_W  = 16;
  localparam int c_EMPTY_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_DATA_W));
  localparam int c_BINS    = 16;
  localparam int c_BIN_W   = (1 << c_DATA_W) / c_BINS;

  logic                    reset = 1'b0;
  logic                    snk_clk = 1'b0;
  logic                    src_clk = 1'b0;
  logic                    snk_ready;
  logic                    snk_valid = 1'b0;
  logic                    snk_sop = 1'b0;
  logic                    snk_eop = 1'b0;
  logic [c_EMPTY_W-1:0]    snk_empty = '0;
  logic [c_DATA_W-1:0]     snk_data = '0;
  logic                    src_ready = 1'b0;
  logic                    src_valid;
  logic                    src_sop;
  logic                    src_eop;
  logic [c_EMPTY_W-1:0]    src_empty;
  logic [c_DATA_W-1:0]     src_data;

  logic [c_DATA_W-1:0] exp_data [$];
  logic                exp_sop [$];
  logic                exp_eop [$];
  logic [c_EMPTY_W-1:0] exp_empty [$];
  int                  bin_hit [0:c_BINS-1];
  int unsigned         seed = 32'h00C0_CDC1;
  int unsigned         seed_src = 32'hCDC1_00C0;
  logic                got_fire = 1'b0;
  logic [c_DATA_W-1:0] got_data;
  logic                got_sop;
  logic                got_eop;
  logic [c_EMPTY_W-1:0] got_empty;
  int                  covered;

  always #12.5 snk_clk = ~snk_clk;
  always #2 src_clk = ~src_clk;

  avst_cdc #(
    .g_DATA_WIDTH (c_DATA_W)
  ) dut (
    .reset_i     (reset),
    .snk_clk_i   (snk_clk),
    .src_clk_i   (src_clk),
    .snk_ready_o (snk_ready),
    .snk_valid_i (snk_valid),
    .snk_sop_i   (snk_sop),
    .snk_eop_i   (snk_eop),
    .snk_empty_i (snk_empty),
    .snk_data_i  (snk_data),
    .src_ready_i (src_ready),
    .src_valid_o (src_valid),
    .src_sop_o   (src_sop),
    .src_eop_o   (src_eop),
    .src_empty_o (src_empty),
    .src_data_o  (src_data)
  );

  function automatic int uncovered_bin(inout int unsigned s);
    int pick;
    int n;
    n = 0;
    for (int i = 0; i < c_BINS; i++)
      if (bin_hit[i] == 0)
        n++;
    if (n == 0)
      return 0;
    pick = int'($urandom(s) % n);
    for (int i = 0; i < c_BINS; i++) begin
      if (bin_hit[i] == 0) begin
        if (pick == 0)
          return i;
        pick--;
      end
    end
    return 0;
  endfunction

  initial begin : proc_master
    int b;
    int unsigned value;
    int guard;
    for (int i = 0; i < c_BINS; i++)
      bin_hit[i] = 0;
    #1;
    reset = 1'b1;
    repeat (2) @(posedge snk_clk);
    #1;
    reset = 1'b0;
    repeat (4) @(posedge snk_clk);

    guard = 0;
    while (covered < c_BINS) begin
      b = uncovered_bin(seed);
      value = (b * c_BIN_W) + ($urandom(seed) % c_BIN_W);
      repeat (int'($urandom(seed) % 4)) @(posedge snk_clk);
      #1;
      snk_data  = c_DATA_W'(value);
      snk_sop   = value[0];
      snk_eop   = value[1];
      snk_empty = value[c_EMPTY_W-1:0];
      snk_valid = 1'b1;
      @(posedge snk_clk);
      while (!(snk_ready && snk_valid)) begin
        @(posedge snk_clk);
        #1;
        guard++;
        if (guard > 100000)
          $fatal(1, "avst_cdc sink timeout");
      end
      exp_data.push_back(snk_data);
      exp_sop.push_back(snk_sop);
      exp_eop.push_back(snk_eop);
      exp_empty.push_back(snk_empty);
      #1;
      snk_valid = 1'b0;
      guard++;
      if (guard > 100000)
        $fatal(1, "avst_cdc did not cover all bins");
    end
  end

  // Sample the source beat in the active region, before the DUT NBA clears valid.
  always @(posedge src_clk) begin : proc_capture
    got_fire  <= src_valid && src_ready;
    got_data  <= src_data;
    got_sop   <= src_sop;
    got_eop   <= src_eop;
    got_empty <= src_empty;
  end

  initial begin : proc_slave
    int b;
    covered = 0;
    src_ready = 1'b0;
    @(posedge src_clk);
    forever begin
      @(posedge src_clk);
      #1;
      if (got_fire) begin
        if (exp_data.size() == 0)
          $fatal(1, "avst_cdc unexpected word %h", got_data);
        if (got_data !== exp_data[0])
          $fatal(1, "avst_cdc data got %h exp %h", got_data, exp_data[0]);
        if (got_sop !== exp_sop[0] || got_eop !== exp_eop[0] || got_empty !== exp_empty[0])
          $fatal(1, "avst_cdc sideband mismatch data %h", got_data);
        b = int'(got_data) / c_BIN_W;
        if (b >= c_BINS)
          b = c_BINS - 1;
        if (bin_hit[b] == 0)
          covered++;
        bin_hit[b]++;
        exp_data.pop_front();
        exp_sop.pop_front();
        exp_eop.pop_front();
        exp_empty.pop_front();
        if (covered == c_BINS && exp_data.size() == 0) begin
          repeat (4) @(posedge src_clk);
          $display("avst_cdc_tb PASS");
          $finish;
        end
      end
      // About 90% ready, matching the VHDL sink probability.
      src_ready = ($urandom(seed_src) % 10) != 0;
    end
  end

  initial begin
    #2ms;
    $fatal(1, "avst_cdc_tb watchdog covered %0d", covered);
  end
endmodule
