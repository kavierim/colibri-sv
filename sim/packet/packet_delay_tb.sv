// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Default packet_delay_tb scenario: g_N_PACKETS*128 packets, random lengths
// up to g_DATA_SYM*8 symbols, random delay, and backpressure on the second
// output packet. Elapsed cycles from the input sop are at least delay_i
// sampled at that sop. A short directed sweep holds delay_i stable so the
// bound is meaningful when several packets are in flight.

`timescale 1ns/1ps

import packet_tb_pkg::*;

module packet_delay_tb;
  localparam int unsigned g_SYM_WIDTH   = 8;
  localparam int unsigned g_DATA_SYM    = 4;
  localparam int unsigned g_N_PACKETS   = 8;
  localparam int unsigned g_DELAY_WIDTH = 5;
  localparam int c_MAX_SYM   = int'(g_DATA_SYM) * 8;
  localparam int c_N_TEST    = int'(g_N_PACKETS) * 128;
  localparam int c_DATA_W    = int'(g_DATA_SYM) * int'(g_SYM_WIDTH);
  localparam int c_EMPTY_W   = colibri_types::avst_empty_width(c_DATA_W, int'(g_SYM_WIDTH));
  localparam int c_NUM_BEATS = int'(g_N_PACKETS) * ((c_MAX_SYM + int'(g_DATA_SYM) - 1) / int'(g_DATA_SYM));

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic [g_DELAY_WIDTH-1:0] delay_i;
  logic [c_DATA_W-1:0]  snk_data_i;
  logic [c_EMPTY_W-1:0] snk_empty_i;
  logic snk_sop_i, snk_eop_i, snk_valid_i, snk_ready_o;
  logic [c_DATA_W-1:0]  src_data_o;
  logic [c_EMPTY_W-1:0] src_empty_o;
  logic src_sop_o, src_eop_o, src_valid_o, src_ready_i;

  logic [7:0] syms [0:c_MAX_SYM-1];
  int         lens [0:c_N_TEST-1];
  int         pkt_in;
  int         pkt_out;
  int         in_pos;
  int         out_pos;
  bit         beat;
  bit         acc;
  int         bp_phase;
  int         cycle;
  int         send_cycle [0:c_N_TEST-1];
  // Delay stays constant while packets are in flight. The DUT applies the
  // live delay_i, so changing it mid-flight releases an older packet early.
  bit         delay_fresh;
  int         guard;

  always #5 clk = ~clk;

  packet_delay #(
    .g_SYM_WIDTH   (g_SYM_WIDTH),
    .g_DATA_SYM    (g_DATA_SYM),
    .g_N_PACKETS   (g_N_PACKETS),
    .g_NUM_BEATS   (c_NUM_BEATS),
    .g_DELAY_WIDTH (g_DELAY_WIDTH)
  ) u_dut (
    .clk_i       (clk),
    .reset_i     (reset),
    .delay_i     (delay_i),
    .snk_data_i  (snk_data_i),
    .snk_empty_i (snk_empty_i),
    .snk_sop_i   (snk_sop_i),
    .snk_eop_i   (snk_eop_i),
    .snk_valid_i (snk_valid_i),
    .snk_ready_o (snk_ready_o),
    .src_data_o  (src_data_o),
    .src_empty_o (src_empty_o),
    .src_sop_o   (src_sop_o),
    .src_eop_o   (src_eop_o),
    .src_valid_o (src_valid_o),
    .src_ready_i (src_ready_i)
  );

  task automatic sample();
    int n_valid;
    int s;
    logic [7:0] got;
    if (!(src_valid_o && src_ready_i))
      return;
    if (bp_phase == 0 && src_eop_o)
      bp_phase = 1;
    else if (bp_phase == 1 && src_sop_o)
      bp_phase = 2;
    else if (bp_phase == 2 && src_eop_o)
      bp_phase = 3;
    n_valid = int'(g_DATA_SYM) - int'(src_empty_o);
    if (out_pos == 0) begin
      if (!src_sop_o)
        $fatal(1, "packet_delay pkt %0d missing sop", pkt_out);
      // VHDL sets delay_i once per output packet and checks that value.
      if ((cycle - send_cycle[pkt_out]) < int'(delay_i))
        $fatal(1, "packet_delay pkt %0d elapsed %0d delay %0d",
               pkt_out, cycle - send_cycle[pkt_out], int'(delay_i));
    end
    for (s = 0; s < n_valid; s++) begin
      got = 8'(be_get(256'(src_data_o), s, 8, int'(g_DATA_SYM)));
      if (got != syms[out_pos])
        $fatal(1, "packet_delay pkt %0d sym %0d got %02x exp %02x",
               pkt_out, out_pos, got, syms[out_pos]);
      out_pos++;
    end
    if (src_eop_o) begin
      if (out_pos != lens[pkt_out])
        $fatal(1, "packet_delay pkt %0d eop at %0d exp %0d", pkt_out, out_pos, lens[pkt_out]);
      pkt_out++;
      out_pos = 0;
      if (!beat && in_pos == 0 && pkt_out == pkt_in)
        delay_fresh = 1'b0;
    end
  endtask

  task automatic drive();
    int n;
    int s;
    int remain;
    if (acc) begin
      acc  = 1'b0;
      beat = 1'b0;
      n = int'(g_DATA_SYM) - int'(snk_empty_i);
      in_pos += n;
      if (in_pos >= lens[pkt_in]) begin
        pkt_in++;
        in_pos = 0;
      end
    end
    if (!beat && pkt_in < c_N_TEST) begin
      remain = lens[pkt_in] - in_pos;
      n = remain;
      if (n > g_DATA_SYM)
        n = g_DATA_SYM;
      snk_data_i  = '0;
      snk_valid_i = 1'b1;
      snk_sop_i   = (in_pos == 0);
      snk_eop_i   = (n == remain);
      snk_empty_i = c_EMPTY_W'(int'(g_DATA_SYM) - n);
      for (s = 0; s < n; s++)
        snk_data_i = c_DATA_W'(be_put(256'(snk_data_i), 32'(syms[in_pos + s]), s, 8, int'(g_DATA_SYM)));
      beat = 1'b1;
    end else if (!beat) begin
      snk_valid_i = 1'b0;
      snk_sop_i   = 1'b0;
      snk_eop_i   = 1'b0;
    end
  endtask

  initial begin
    int i;
    int d;
    delay_i     = '0;
    snk_sop_i   = 1'b0;
    snk_eop_i   = 1'b0;
    snk_valid_i = 1'b0;
    snk_data_i  = '0;
    snk_empty_i = '0;
    src_ready_i = 1'b1;
    beat        = 1'b0;
    acc         = 1'b0;
    pkt_in      = 0;
    pkt_out     = 0;
    in_pos      = 0;
    out_pos     = 0;
    bp_phase    = 3;
    cycle       = 0;
    guard       = 0;
    seed_rand(32'hDE1A_0001);
    for (i = 0; i < c_MAX_SYM; i++)
      syms[i] = urand8();
    for (i = 0; i < c_N_TEST; i++)
      lens[i] = urand(1, c_MAX_SYM);
    @(posedge clk);
    wait (reset == 1'b0);
    // Directed delays, one packet at a time, before the random run reuses pkt 0.
    // The random run below is the VHDL scenario; this sweep pins the bound.
    for (d = 0; d < 5; d++) begin
      int unsigned dv;
      int unsigned slen;
      int          scyc;
      // Non-zero first, so the delay check sees a positive programmed delay.
      dv = (d == 0) ? 1 : (d == 1) ? 3 : (d == 2) ? 8 : (d == 3) ? 31 : 0;
      slen = urand(1, c_MAX_SYM);
      delay_i = g_DELAY_WIDTH'(dv);
      lens[0] = slen;
      // fall through by temporarily limiting is messy; send inline below
      begin
        int pos;
        bit  local_beat;
        bit  got;
        pos = 0;
        local_beat = 1'b0;
        got = 1'b0;
        scyc = 0;
        while (!got) begin
          @(negedge clk);
          src_ready_i = 1'b1;
          if (!local_beat && pos < slen) begin
            int n;
            int s;
            n = slen - pos;
            if (n > g_DATA_SYM)
              n = g_DATA_SYM;
            snk_data_i  = '0;
            snk_valid_i = 1'b1;
            snk_sop_i   = (pos == 0);
            snk_eop_i   = (pos + n == slen);
            snk_empty_i = c_EMPTY_W'(int'(g_DATA_SYM) - n);
            for (s = 0; s < n; s++)
              snk_data_i = c_DATA_W'(be_put(256'(snk_data_i), 32'(syms[pos + s]), s, 8, int'(g_DATA_SYM)));
            local_beat = 1'b1;
          end else if (!local_beat) begin
            snk_valid_i = 1'b0;
            snk_sop_i   = 1'b0;
            snk_eop_i   = 1'b0;
          end
          @(posedge clk);
          cycle++;
          if (local_beat && snk_valid_i && snk_ready_o) begin
            if (snk_sop_i)
              scyc = cycle;
            pos += int'(g_DATA_SYM) - int'(snk_empty_i);
            local_beat = 1'b0;
          end
          if (src_valid_o && src_ready_i && src_sop_o) begin
            if ((cycle - scyc) < dv)
              $fatal(1, "packet_delay directed delay %0d elapsed %0d", dv, cycle - scyc);
          end
          if (src_valid_o && src_ready_i && src_eop_o)
            got = 1'b1;
          guard++;
          if (guard > 100000)
            $fatal(1, "packet_delay directed stall");
        end
        snk_valid_i = 1'b0;
        snk_sop_i   = 1'b0;
        snk_eop_i   = 1'b0;
        repeat (4) @(posedge clk);
      end
    end
    // VHDL scenario. Backpressure arms on the first random-run eop.
    bp_phase = 0;
    pkt_in   = 0;
    pkt_out  = 0;
    in_pos   = 0;
    out_pos  = 0;
    beat       = 1'b0;
    acc        = 1'b0;
    delay_fresh = 1'b0;
    while (pkt_out < c_N_TEST) begin
      @(negedge clk);
      if (!delay_fresh && pkt_in == pkt_out && in_pos == 0 && !beat) begin
        delay_i     = g_DELAY_WIDTH'(urand(0, (1 << g_DELAY_WIDTH) - 1));
        delay_fresh = 1'b1;
      end
      if (bp_phase == 2)
        src_ready_i = 1'($urandom_range(1, 0));
      else
        src_ready_i = 1'b1;
      drive();
      @(posedge clk);
      cycle++;
      if (beat && snk_valid_i && snk_ready_o && snk_sop_i)
        send_cycle[pkt_in] = cycle;
      acc = beat && snk_valid_i && snk_ready_o;
      sample();
      guard++;
      if (guard > 2_000_000)
        $fatal(1, "packet_delay stalled in=%0d out=%0d", pkt_in, pkt_out);
    end
    $display("PASS packet_delay_tb");
    $finish;
  end

  initial begin
    reset = 1'b1;
    @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
  end

  initial begin
    #50ms;
    $fatal(1, "packet_delay_tb watchdog");
  end
endmodule
