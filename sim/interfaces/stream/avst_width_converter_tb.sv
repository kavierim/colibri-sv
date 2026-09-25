// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Avalon-ST width converter. Incremental packets, then 10 random packets.
// Symbols are first-symbol-in-MSB, matching the UVVM BFM configuration.
module avst_width_converter_harness #(
  parameter int unsigned g_SEED       = 42,
  parameter int unsigned g_SYM_WIDTH  = 8,
  parameter int unsigned g_INPUT_SYM  = 4,
  parameter int unsigned g_OUTPUT_SYM = 4,
  localparam int c_IN_W  = int'(g_SYM_WIDTH) * int'(g_INPUT_SYM),
  localparam int c_OUT_W = int'(g_SYM_WIDTH) * int'(g_OUTPUT_SYM),
  localparam int c_IN_E  = colibri_types::avst_empty_width(c_IN_W, int'(g_SYM_WIDTH)),
  localparam int c_OUT_E = colibri_types::avst_empty_width(c_OUT_W, int'(g_SYM_WIDTH)),
  localparam int c_MAX   = 1024,
  localparam int c_N_INC = ((g_INPUT_SYM > g_OUTPUT_SYM) ? g_INPUT_SYM : g_OUTPUT_SYM) + 1,
  localparam int c_N_RND = 10
) (
  output logic done
);

  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic                  snk_ready;
  logic                  snk_valid = 1'b0;
  logic                  snk_sop = 1'b0;
  logic                  snk_eop = 1'b0;
  logic [c_IN_E-1:0]     snk_empty = '0;
  logic [c_IN_W-1:0]     snk_data = '0;
  logic                  src_ready = 1'b1;
  logic                  src_valid;
  logic                  src_sop;
  logic                  src_eop;
  logic [c_OUT_E-1:0]    src_empty;
  logic [c_OUT_W-1:0]    src_data;

  logic [g_SYM_WIDTH-1:0] syms [$];
  int                     lens [$];
  int                     plen [$];
  int                     exp_i;
  int                     pkt_got;
  int                     pkt_left;
  bit                     saw_sop;

  always #5 clk = ~clk;

  avst_width_converter #(
    .g_SYM_WIDTH  (g_SYM_WIDTH),
    .g_INPUT_SYM  (g_INPUT_SYM),
    .g_OUTPUT_SYM (g_OUTPUT_SYM)
  ) dut (
    .clk_i       (clk),
    .reset_i     (reset),
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

  function automatic logic [c_IN_W-1:0] pack_word(input int base, input int n);
    logic [c_IN_W-1:0] w;
    w = '0;
    for (int i = 0; i < n; i++)
      w[c_IN_W-1 - i*int'(g_SYM_WIDTH) -: g_SYM_WIDTH] = syms[base+i];
    return w;
  endfunction

  task automatic fail(input string msg);
    $fatal(1, "avst_width_converter sym %0d in %0d out %0d: %s",
           g_SYM_WIDTH, g_INPUT_SYM, g_OUTPUT_SYM, msg);
  endtask

  always @(posedge clk) begin : proc_check
    int n;
    logic [g_SYM_WIDTH-1:0] got;
    if (!reset && src_valid && src_ready) begin
      n = int'(g_OUTPUT_SYM) - int'(src_empty);
      if ((n < 1) || (n > int'(g_OUTPUT_SYM)))
        fail("bad empty");
      if (!src_eop && (src_empty != '0))
        fail("empty before end of packet");
      if (!saw_sop) begin
        if (!src_sop)
          fail("missing start of packet");
        saw_sop = 1'b1;
      end else if (src_sop) begin
        fail("repeated start of packet");
      end
      for (int i = 0; i < n; i++) begin
        got = src_data[c_OUT_W-1 - i*int'(g_SYM_WIDTH) -: g_SYM_WIDTH];
        if (exp_i >= syms.size())
          fail("extra symbol");
        if (got !== syms[exp_i])
          $fatal(1, "avst_width_converter sym %0d in %0d out %0d mismatch at %0d got %h exp %h",
                 g_SYM_WIDTH, g_INPUT_SYM, g_OUTPUT_SYM, exp_i, got, syms[exp_i]);
        exp_i++;
        pkt_got++;
      end
      if (src_eop) begin
        if (pkt_got != lens[0])
          $fatal(1, "avst_width_converter sym %0d in %0d out %0d length got %0d exp %0d",
                 g_SYM_WIDTH, g_INPUT_SYM, g_OUTPUT_SYM, pkt_got, lens[0]);
        lens.pop_front();
        pkt_got = 0;
        saw_sop = 1'b0;
        pkt_left--;
      end
    end
  end

  initial begin : proc_seq
    int unsigned rnd;
    int len;
    int base;
    int n;
    int guard;
    int unsigned useed;
    done    = 1'b0;
    exp_i   = 0;
    pkt_got = 0;
    saw_sop = 1'b0;
    useed   = g_SEED;
    for (int i = 0; i < c_N_INC; i++) begin
      lens.push_back(i + 1);
      plen.push_back(i + 1);
      for (int j = 0; j <= i; j++)
        syms.push_back(g_SYM_WIDTH'(j + 1));
    end
    for (int i = 0; i < c_N_RND; i++) begin
      len = 1 + int'($urandom(useed) % c_MAX);
      lens.push_back(len);
      plen.push_back(len);
      for (int j = 0; j < len; j++) begin
        rnd = $urandom(useed);
        syms.push_back(g_SYM_WIDTH'(rnd));
      end
    end
    pkt_left = lens.size();

    repeat (10) @(posedge clk);
    #1;
    reset = 1'b0;
    repeat (2) @(posedge clk);

    base = 0;
    begin
      int npackets;
      npackets = plen.size();
      for (int p = 0; p < npackets; p++) begin
        len = plen[p];
        while (len > 0) begin
          n = int'(g_INPUT_SYM);
          if (n > len)
            n = len;
          #1;
          snk_valid = 1'b1;
          snk_sop   = (len == plen[p]);
          snk_eop   = (n == len);
          snk_empty = c_IN_E'(int'(g_INPUT_SYM) - n);
          snk_data  = pack_word(base, n);
          @(posedge clk);
          guard = 0;
          while (!snk_ready) begin
            @(posedge clk);
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
        repeat (10) @(posedge clk);
      end
    end

    guard = 0;
    while (pkt_left != 0) begin
      @(posedge clk);
      #1;
      guard++;
      if (guard > 200000)
        fail("output timeout");
    end
    repeat (4) @(posedge clk);
    done = 1'b1;
  end

endmodule

module avst_width_converter_tb;
  localparam int N = 11;
  logic [N-1:0] done;

  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(8),  .g_INPUT_SYM(4),  .g_OUTPUT_SYM(4))  u0 (.done(done[0]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(8),  .g_INPUT_SYM(2),  .g_OUTPUT_SYM(4))  u1 (.done(done[1]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(8),  .g_INPUT_SYM(4),  .g_OUTPUT_SYM(2))  u2 (.done(done[2]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(1),  .g_INPUT_SYM(1),  .g_OUTPUT_SYM(1))  u3 (.done(done[3]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(1),  .g_INPUT_SYM(32), .g_OUTPUT_SYM(1))  u4 (.done(done[4]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(1),  .g_INPUT_SYM(1),  .g_OUTPUT_SYM(32)) u5 (.done(done[5]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(13), .g_INPUT_SYM(5),  .g_OUTPUT_SYM(7))  u6 (.done(done[6]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(13), .g_INPUT_SYM(7),  .g_OUTPUT_SYM(5))  u7 (.done(done[7]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(8),  .g_INPUT_SYM(16), .g_OUTPUT_SYM(9))  u8 (.done(done[8]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(8),  .g_INPUT_SYM(16), .g_OUTPUT_SYM(18)) u9 (.done(done[9]));
  avst_width_converter_harness #(.g_SEED(42), .g_SYM_WIDTH(8),  .g_INPUT_SYM(16), .g_OUTPUT_SYM(27)) u10 (.done(done[10]));

  initial begin
    wait (&done);
    $display("avst_width_converter_tb PASS");
    $finish;
  end

  initial begin
    #20ms;
    $fatal(1, "avst_width_converter_tb watchdog");
  end
endmodule
