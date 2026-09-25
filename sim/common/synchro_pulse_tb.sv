// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Pulse synchronizer. Every sim/common/run.py configuration:
// stages 2, 3 and 20, source and destination periods 6 ns and 50 ns.
module synchro_pulse_tb;

  localparam int c_NCFG   = 12;
  localparam int c_NPULSE = 100;

  bit [c_NCFG-1:0] cfg_done;

  for (genvar gi = 0; gi < c_NCFG; gi++) begin : gen_cfg
    localparam int c_STAGES = (gi < 4) ? 2 : ((gi < 8) ? 3 : 20);
    localparam int c_PAIR   = gi % 4;
    localparam int c_SRC_NS = (c_PAIR == 0 || c_PAIR == 1) ? 6 : 50;
    localparam int c_DST_NS = (c_PAIR == 0 || c_PAIR == 2) ? 6 : 50;
    localparam int c_RATIO  = colibri_utils::div_ceil(2 * c_DST_NS, c_SRC_NS);
    localparam int c_GAP    = colibri_utils::maximum(c_RATIO - 1, 1);
    localparam int c_MAX_NS = colibri_utils::maximum(c_DST_NS, c_SRC_NS);
    // 5 * max(period) source clocks: a pulse wider than one destination cycle.
    localparam int c_WIDE   = 5 * c_MAX_NS;

    logic src_clk;
    logic dst_clk;
    logic pulse_in;
    logic pulse_out;

    initial begin
      src_clk = 1'b1;
      forever begin
        #(c_SRC_NS / 2.0) src_clk = 1'b0;
        #(c_SRC_NS / 2.0) src_clk = 1'b1;
      end
    end

    initial begin
      dst_clk = 1'b1;
      forever begin
        #(c_DST_NS / 2.0) dst_clk = 1'b0;
        #(c_DST_NS / 2.0) dst_clk = 1'b1;
      end
    end

    synchro_pulse #(
      .g_NUM_STAGES(c_STAGES)
    ) u_synchro_pulse (
      .src_clk_i(src_clk),
      .dst_clk_i(dst_clk),
      .pulse_i(pulse_in),
      .pulse_o(pulse_out)
    );

    initial begin : proc_input
      pulse_in = 1'b0;
      @(posedge dst_clk);
      @(posedge src_clk);
      #1;
      pulse_in = 1'b1;
      @(posedge src_clk);
      #1;
      pulse_in = 1'b0;
      @(negedge pulse_out);

      for (int i = 1; i <= c_NPULSE; i++) begin
        repeat (c_GAP) @(posedge src_clk);
        #1;
        pulse_in = 1'b1;
        @(posedge src_clk);
        #1;
        pulse_in = 1'b0;
      end

      repeat (c_STAGES * c_RATIO) @(posedge src_clk);
      #1;
      pulse_in = 1'b1;
      repeat (c_WIDE) @(posedge src_clk);
      #1;
      pulse_in = 1'b0;
    end

    initial begin : proc_check
      bit seen;

      @(posedge dst_clk);
      if (pulse_out !== 1'b0)
        $fatal(1, "cfg %0d init: output was not 0", gi);

      @(posedge pulse_in);
      repeat (c_STAGES) @(posedge dst_clk);
      wait_high(2 * c_MAX_NS, seen);
      if (!seen || pulse_out !== 1'b1)
        $fatal(1, "cfg %0d: single pulse did not propagate", gi);
      @(posedge dst_clk);
      #(c_DST_NS / 10.0);
      if (pulse_out !== 1'b0)
        $fatal(1, "cfg %0d: destination pulse lasted longer than 1 cycle", gi);

      @(posedge pulse_in);
      repeat (c_STAGES) @(posedge dst_clk);
      for (int i = 1; i <= c_NPULSE; i++) begin
        wait_high(2 * c_MAX_NS, seen);
        if (!seen || pulse_out !== 1'b1)
          $fatal(1, "cfg %0d: consecutive pulse %0d did not propagate", gi, i);
        @(posedge dst_clk);
        #(c_DST_NS / 10.0);
        if (pulse_out !== 1'b0)
          $fatal(1, "cfg %0d: destination pulse %0d lasted longer than 1 cycle", gi, i);
      end

      wait_high(100 * c_STAGES * c_DST_NS, seen);
      if (!seen || pulse_out !== 1'b1)
        $fatal(1, "cfg %0d: wider pulse did not propagate", gi);
      @(posedge dst_clk);
      #(c_DST_NS / 10.0);
      if (pulse_out !== 1'b0)
        $fatal(1, "cfg %0d: wider pulse response lasted longer than 1 cycle", gi);

      wait_high(100 * c_STAGES * c_DST_NS, seen);
      if (seen || pulse_out !== 1'b0)
        $fatal(1, "cfg %0d: unexpected pulse on the output", gi);

      cfg_done[gi] = 1'b1;
    end

    task automatic wait_high(input int timeout_ns, output bit seen);
      int guard;
      guard = timeout_ns;
      while (pulse_out !== 1'b1 && guard > 0) begin
        #1;
        guard = guard - 1;
      end
      seen = (pulse_out === 1'b1);
    endtask
  end

  initial begin
    cfg_done = '0;
    wait (&cfg_done);
    $display("PASS synchro_pulse_tb");
    $finish;
  end

  initial begin
    #2ms;
    if (!(&cfg_done))
      $fatal(1, "timeout, done mask %b", cfg_done);
  end

endmodule
