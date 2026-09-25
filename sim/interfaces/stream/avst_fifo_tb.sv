// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Avalon-ST FIFO, synchronous and asynchronous clocks.
// Incremental packets of length 1 .. g_DATA_SYM+1, then 10 random packets.
module avst_fifo_harness #(
  parameter int unsigned g_SEED         = 42,
  parameter int unsigned g_SYM_WIDTH    = 8,
  parameter int unsigned g_DATA_SYM     = 16,
  parameter bit          g_ASYNC_CLOCKS = 1'b0,
  localparam int c_DATA_W = int'(g_DATA_SYM) * int'(g_SYM_WIDTH),
  localparam int c_EMPTY  = colibri_types::avst_empty_width(c_DATA_W, int'(g_SYM_WIDTH)),
  localparam int c_MAX    = 1024,
  localparam int c_N_INC  = int'(g_DATA_SYM) + 1,
  localparam int c_N_RND  = 10
) (
  output logic done
);

  logic                   snk_clk = 1'b0;
  logic                   src_clk = 1'b0;
  logic                   snk_reset = 1'b1;
  logic                   snk_ready;
  logic                   snk_valid = 1'b0;
  logic                   snk_sop = 1'b0;
  logic                   snk_eop = 1'b0;
  logic [c_EMPTY-1:0]     snk_empty = '0;
  logic [c_DATA_W-1:0]    snk_data = '0;
  logic                   src_ready = 1'b1;
  logic                   src_valid;
  logic                   src_sop;
  logic                   src_eop;
  logic [c_EMPTY-1:0]     src_empty;
  logic [c_DATA_W-1:0]    src_data;

  logic [g_SYM_WIDTH-1:0] syms [$];
  int                     lens [$];
  int                     plen [$];
  int                     exp_i;
  int                     pkt_got;
  int                     pkt_left;
  bit                     saw_sop;

  always #5 snk_clk = ~snk_clk;
  if (g_ASYNC_CLOCKS) begin : gen_async
    always #4 src_clk = ~src_clk;
  end else begin : gen_sync
    assign src_clk = snk_clk;
  end

  avst_fifo #(
    .g_SYM_WIDTH    (g_SYM_WIDTH),
    .g_DATA_SYM     (g_DATA_SYM),
    .g_ASYNC_CLOCKS (g_ASYNC_CLOCKS)
  ) dut (
    .snk_clk_i   (snk_clk),
    .src_clk_i   (src_clk),
    .snk_reset_i (snk_reset),
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

  function automatic logic [c_DATA_W-1:0] pack_word(input int base, input int n);
    logic [c_DATA_W-1:0] w;
    w = '0;
    for (int i = 0; i < n; i++)
      w[c_DATA_W-1 - i*int'(g_SYM_WIDTH) -: g_SYM_WIDTH] = syms[base+i];
    return w;
  endfunction

  task automatic fail(input string msg);
    $fatal(1, "avst_fifo async %0d sym %0d data %0d: %s",
           g_ASYNC_CLOCKS, g_SYM_WIDTH, g_DATA_SYM, msg);
  endtask

  always @(posedge src_clk) begin : proc_check
    int n;
    logic [g_SYM_WIDTH-1:0] got;
    if (src_valid && src_ready) begin
      n = int'(g_DATA_SYM) - int'(src_empty);
      if ((n < 1) || (n > int'(g_DATA_SYM)))
        fail("bad empty");
      if (!saw_sop) begin
        if (!src_sop)
          fail("missing start of packet");
        saw_sop = 1'b1;
      end else if (src_sop) begin
        fail("repeated start of packet");
      end
      for (int i = 0; i < n; i++) begin
        got = src_data[c_DATA_W-1 - i*int'(g_SYM_WIDTH) -: g_SYM_WIDTH];
        if (exp_i >= syms.size())
          fail("extra symbol");
        if (got !== syms[exp_i])
          $fatal(1, "avst_fifo async %0d mismatch at %0d got %h exp %h",
                 g_ASYNC_CLOCKS, exp_i, got, syms[exp_i]);
        exp_i++;
        pkt_got++;
      end
      if (src_eop) begin
        if (pkt_got != lens[0])
          $fatal(1, "avst_fifo async %0d length got %0d exp %0d",
                 g_ASYNC_CLOCKS, pkt_got, lens[0]);
        lens.pop_front();
        pkt_got = 0;
        saw_sop = 1'b0;
        pkt_left--;
      end else if (src_empty != '0) begin
        fail("empty before end of packet");
      end
    end
  end

  initial begin : proc_seq
    int unsigned useed;
    int len;
    int base;
    int n;
    int guard;
    int npackets;
    done    = 1'b0;
    exp_i   = 0;
    pkt_got = 0;
    saw_sop = 1'b0;
    useed   = g_SEED ^ {31'b0, g_ASYNC_CLOCKS};
    for (int i = 0; i < c_N_INC; i++) begin
      lens.push_back(i + 1);
      plen.push_back(i + 1);
      for (int j = 0; j <= i; j++)
        syms.push_back(g_SYM_WIDTH'(j));
    end
    for (int i = 0; i < c_N_RND; i++) begin
      len = 1 + int'($urandom(useed) % c_MAX);
      lens.push_back(len);
      plen.push_back(len);
      for (int j = 0; j < len; j++)
        syms.push_back(g_SYM_WIDTH'($urandom(useed)));
    end
    npackets = plen.size();
    pkt_left = npackets;

    repeat (10) @(posedge snk_clk);
    #1;
    snk_reset = 1'b0;
    repeat (4) @(posedge snk_clk);

    base = 0;
    for (int p = 0; p < npackets; p++) begin
        len = plen[p];
      while (len > 0) begin
        n = int'(g_DATA_SYM);
        if (n > len)
          n = len;
        #1;
        snk_valid = 1'b1;
        snk_sop   = (len == plen[p]);
        snk_eop   = (n == len);
        snk_empty = c_EMPTY'(int'(g_DATA_SYM) - n);
        snk_data  = pack_word(base, n);
        @(posedge snk_clk);
        guard = 0;
        while (!snk_ready) begin
          @(posedge snk_clk);
          guard++;
          if (guard > 100000)
            fail("ready timeout");
        end
        base += n;
        len  -= n;
      end
      #1;
      snk_valid = 1'b0;
      snk_sop   = 1'b0;
      snk_eop   = 1'b0;
      snk_empty = '0;
      repeat (10) @(posedge snk_clk);
    end

    guard = 0;
    while (pkt_left != 0) begin
      @(posedge src_clk);
      #1;
      guard++;
      if (guard > 400000)
        fail("output timeout");
    end
    repeat (8) @(posedge src_clk);
    done = 1'b1;
  end

endmodule

module avst_fifo_tb;
  logic [3:0] done;

  avst_fifo_harness #(.g_SEED(42), .g_SYM_WIDTH(8), .g_DATA_SYM(16), .g_ASYNC_CLOCKS(1'b0)) u0 (.done(done[0]));
  avst_fifo_harness #(.g_SEED(42), .g_SYM_WIDTH(1), .g_DATA_SYM(8),  .g_ASYNC_CLOCKS(1'b0)) u1 (.done(done[1]));
  avst_fifo_harness #(.g_SEED(42), .g_SYM_WIDTH(8), .g_DATA_SYM(16), .g_ASYNC_CLOCKS(1'b1)) u2 (.done(done[2]));
  avst_fifo_harness #(.g_SEED(42), .g_SYM_WIDTH(1), .g_DATA_SYM(8),  .g_ASYNC_CLOCKS(1'b1)) u3 (.done(done[3]));

  initial begin
    wait (&done);
    $display("avst_fifo_tb PASS");
    $finish;
  end

  initial begin
    #20ms;
    $fatal(1, "avst_fifo_tb watchdog");
  end
endmodule
