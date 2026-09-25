// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Transmitter stimulus from aurora_tx_tb.vhdl ("test_alive"): 11 packets of
// three 64-bit beats into a 4-lane, 32-bit gearbox. Checks every beat is
// accepted and each lane presents a non-zero stream afterwards.

`timescale 1ns/1ps

module aurora_tx_tb;

  localparam int c_N_LANES    = 4;
  localparam int c_LANE_WIDTH = 32;
  localparam int c_DATA_W     = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_EMPTY_W    = colibri_utils::log2ceil(c_DATA_W / 8);
  logic                      snk_clk = 1'b0;
  logic                      src_clk = 1'b0;
  logic                      reset = 1'b1;
  logic                      snk_sop = 1'b0;
  logic                      snk_eop = 1'b0;
  logic                      snk_valid = 1'b0;
  logic                      snk_ready;
  logic [c_DATA_W-1:0]       snk_data = '0;
  logic [c_EMPTY_W-1:0]      snk_empty = '0;
  logic [c_LANE_WIDTH-1:0]   src_data [0:c_N_LANES-1];
  logic [c_N_LANES-1:0]      src_valid;
  logic [c_N_LANES-1:0]      src_ready = {c_N_LANES{1'b1}};

  int accepted;
  int valid_cnt [0:c_N_LANES-1];
  bit nonzero [0:c_N_LANES-1];

  always #2500ps snk_clk = ~snk_clk;
  always #2500ps src_clk = ~src_clk;

  aurora_tx #(
    .g_N_LANES(c_N_LANES),
    .g_LANE_WIDTH(c_LANE_WIDTH)
  ) dut (
    .snk_clk_i(snk_clk),
    .snk_reset_i(reset),
    .src_clk_i(src_clk),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .snk_data_i(snk_data),
    .snk_empty_i(snk_empty),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .src_ready_i(src_ready)
  );

  task automatic snk_tick;
    @(posedge snk_clk);
    #1ps;
  endtask

  task automatic send_beat(
    input logic [c_DATA_W-1:0] data,
    input logic                sop,
    input logic                eop
  );
    int guard;
    guard = 0;
    while (snk_ready != 1'b1) begin
      snk_tick();
      guard++;
      if (guard > 5000)
        $fatal(1, "aurora_tx snk_ready timeout");
    end
    snk_data  = data;
    snk_empty = '0;
    snk_sop   = sop;
    snk_eop   = eop;
    snk_valid = 1'b1;
    snk_tick();
    accepted++;
    snk_valid = 1'b0;
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
  endtask

  initial begin : proc_src_mon
    for (int lane = 0; lane < c_N_LANES; lane++) begin
      valid_cnt[lane] = 0;
      nonzero[lane]   = 1'b0;
    end
    forever begin
      @(posedge src_clk);
      #1ps;
      if (!reset) begin
        for (int lane = 0; lane < c_N_LANES; lane++) begin
          if (src_valid[lane]) begin
            valid_cnt[lane]++;
            if (src_data[lane] != '0)
              nonzero[lane] = 1'b1;
          end
        end
      end
    end
  end

  initial begin : proc_main
    bit lanes_ok;
    accepted = 0;
    reset = 1'b1;
    repeat (5) @(posedge snk_clk);
    reset = 1'b0;

    for (int i = 0; i < 11; i++) begin
      send_beat(64'haabb_ccdd_0011_2244, 1'b1, 1'b0);
      send_beat(64'hffbb_ccdd_0011_22ee, 1'b0, 1'b0);
      send_beat(64'h77bb_ccdd_0011_2288, 1'b0, 1'b1);
    end

    if (accepted != 33)
      $fatal(1, "accepted %0d beats, expected 33", accepted);

    begin
      int guard;
      guard = 0;
      lanes_ok = 1'b0;
      while (!lanes_ok) begin
        @(posedge src_clk);
        #1ps;
        lanes_ok = 1'b1;
        for (int lane = 0; lane < c_N_LANES; lane++) begin
          if ((valid_cnt[lane] < 20) || !nonzero[lane])
            lanes_ok = 1'b0;
        end
        guard++;
        if (guard > 20000)
          $fatal(1, "aurora_tx lane activity timeout");
      end
    end

    $display("PASS aurora_tx_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #100us;
    $fatal(1, "aurora_tx_tb timeout");
  end

endmodule
