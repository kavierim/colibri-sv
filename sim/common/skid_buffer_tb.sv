// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Stimulus for skid_buffer.psl. Holds the sink beat while stalled, and
// leaves valid low the cycle after reset.
module skid_buffer_tb;

  localparam int c_W    = 32;
  localparam int c_N    = 40;
  localparam int c_KEEP = c_W / 8;
  localparam int c_EMPTY = colibri_utils::downto_width(colibri_utils::log2ceil(c_W / 8));

  typedef struct packed {
    logic [c_W-1:0]     data;
    logic [c_EMPTY-1:0] empty;
    logic [c_KEEP-1:0]  keep;
    logic               sop;
    logic               eop;
  } beat_t;

  logic                  clk_i;
  logic                  reset_i;
  logic [c_W-1:0]        snk_data_i;
  logic [c_EMPTY-1:0]    snk_empty_i;
  logic [c_KEEP-1:0]     snk_keep_i;
  logic                  snk_sop_i;
  logic                  snk_eop_i;
  logic                  snk_valid_i;
  logic                  snk_ready_o;
  logic [c_W-1:0]        src_data_o;
  logic [c_EMPTY-1:0]    src_empty_o;
  logic [c_KEEP-1:0]     src_keep_o;
  logic                  src_sop_o;
  logic                  src_eop_o;
  logic                  src_valid_o;
  logic                  src_ready_i;

  beat_t sent [0:c_N-1];
  int    sent_n;
  int    got_n;
  int    stall_left;
  logic  go;
  logic  hold_beat;

  skid_buffer #(
    .g_DATA_WIDTH(c_W)
  ) dut (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .snk_data_i(snk_data_i),
    .snk_empty_i(snk_empty_i),
    .snk_keep_i(snk_keep_i),
    .snk_sop_i(snk_sop_i),
    .snk_eop_i(snk_eop_i),
    .snk_valid_i(snk_valid_i),
    .snk_ready_o(snk_ready_o),
    .src_data_o(src_data_o),
    .src_empty_o(src_empty_o),
    .src_keep_o(src_keep_o),
    .src_sop_o(src_sop_o),
    .src_eop_o(src_eop_o),
    .src_valid_o(src_valid_o),
    .src_ready_i(src_ready_i)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    reset_i     = 1'b1;
    snk_valid_i = 1'b0;
    snk_data_i  = '0;
    snk_empty_i = '0;
    snk_keep_i  = '0;
    snk_sop_i   = 1'b0;
    snk_eop_i   = 1'b0;
    src_ready_i = 1'b1;
    sent_n      = 0;
    got_n       = 0;
    stall_left  = 6;
    go          = 1'b0;
    hold_beat   = 1'b0;
    repeat (4) @(posedge clk_i);
    @(negedge clk_i);
    reset_i = 1'b0;
    @(posedge clk_i);
    @(negedge clk_i);
    go = 1'b1;
  end

  always @(negedge clk_i) begin
    if (!go) begin
      src_ready_i <= 1'b1;
    end else if (stall_left > 0) begin
      src_ready_i <= 1'b0;
      stall_left  <= stall_left - 1;
    end else begin
      src_ready_i <= 1'b1;
      if (($urandom % 2) == 1)
        stall_left <= $urandom_range(1, 8);
    end
  end

  // Sample the stall at the clock. The next cycle must keep the beat,
  // even if ready rises in that same clock's update.
  always @(posedge clk_i) begin
    if (!go)
      hold_beat <= 1'b0;
    else
      hold_beat <= snk_valid_i && !snk_ready_o;
  end

  always @(negedge clk_i) begin
    if (!go) begin
      snk_valid_i <= 1'b0;
    end else if (hold_beat) begin
      // PSL assume: keep valid and data while the sink is stalled.
    end else if (sent_n < c_N) begin
      beat_t b;
      b.data  = $urandom;
      b.empty = c_EMPTY'($urandom);
      b.keep  = c_KEEP'($urandom);
      b.sop   = 1'(($urandom % 2) == 0);
      b.eop   = 1'(($urandom % 2) == 0);
      snk_data_i  <= b.data;
      snk_empty_i <= b.empty;
      snk_keep_i  <= b.keep;
      snk_sop_i   <= b.sop;
      snk_eop_i   <= b.eop;
      snk_valid_i <= 1'b1;
      sent[sent_n] = b;
      sent_n = sent_n + 1;
    end else begin
      snk_valid_i <= 1'b0;
    end
  end

  always @(posedge clk_i) begin
    if (!reset_i && src_valid_o && src_ready_i) begin
      beat_t got;
      if (got_n >= sent_n)
        $fatal(1, "output beat before it was queued");
      got.data  = src_data_o;
      got.empty = src_empty_o;
      got.keep  = src_keep_o;
      got.sop   = src_sop_o;
      got.eop   = src_eop_o;
      if (got !== sent[got_n])
        $fatal(1, "beat %0d mismatch", got_n);
      got_n <= got_n + 1;
    end
  end

  initial begin
    wait (got_n == c_N);
    repeat (4) @(posedge clk_i);
    $display("PASS skid_buffer_tb");
    $finish;
  end

  initial begin
    #200us;
    if (got_n != c_N)
      $fatal(1, "timeout after %0d of %0d beats", got_n, c_N);
  end

endmodule
