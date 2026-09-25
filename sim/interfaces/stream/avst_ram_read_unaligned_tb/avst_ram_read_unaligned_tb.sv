// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Unaligned Avalon-ST RAM reader. Same cases as avst_ram_read_unaligned_tb:
// multi-beat, short aligned, single-beat, short unaligned, full length,
// and back-pressure including the edge cases.
module avst_ram_read_unaligned_harness #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 128,
  localparam int c_DATA_W  = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_BYTES   = int'(g_RAM_DEPTH) * int'(g_WORD_BYTES),
  localparam int c_BADDR_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_BYTES)),
  localparam int c_ADDR_W  = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_RAM_DEPTH))),
  localparam int c_LEN_W   = colibri_utils::log2ceil(c_BYTES) + 1
) (
  output logic done
);

  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    back_pressure = 1'b0;
  logic                    src_ready;
  logic [c_DATA_W-1:0]     src_data;
  logic [c_EMPTY_W-1:0]    src_empty;
  logic                    src_sop;
  logic                    src_eop;
  logic                    src_valid;
  logic [c_BADDR_W-1:0]    start_addr = '0;
  logic [c_LEN_W-1:0]      rd_length = '0;
  logic                    rd_start = 1'b0;
  logic                    rd_busy;
  logic                    rd_en;
  logic [c_ADDR_W-1:0]     rd_addr;
  logic [c_DATA_W-1:0]     rd_data = '0;

  logic [g_BYTE_WIDTH-1:0] ram [0:c_BYTES-1];
  int                      exp_base [$];
  int                      exp_len [$];
  int                      cur_base;
  int                      cur_len;
  int                      cur_got;
  bit                      cur_on;
  int unsigned             seed;

  always #5 clk = ~clk;
  assign src_ready = ~back_pressure;

  avst_ram_read_unaligned #(
    .g_BYTE_WIDTH (g_BYTE_WIDTH),
    .g_WORD_BYTES (g_WORD_BYTES),
    .g_RAM_DEPTH  (g_RAM_DEPTH)
  ) dut (
    .clk_i        (clk),
    .reset_i      (reset),
    .src_data_o   (src_data),
    .src_empty_o  (src_empty),
    .src_sop_o    (src_sop),
    .src_eop_o    (src_eop),
    .src_valid_o  (src_valid),
    .src_ready_i  (src_ready),
    .start_addr_i (start_addr),
    .length_i     (rd_length),
    .start_i      (rd_start),
    .busy_o       (rd_busy),
    .rd_en_o      (rd_en),
    .rd_addr_o    (rd_addr),
    .rd_data_i    (rd_data)
  );

  task automatic fail(input string msg);
    $fatal(1, "avst_ram_read_unaligned b%0d w%0d d%0d: %s",
           g_BYTE_WIDTH, g_WORD_BYTES, g_RAM_DEPTH, msg);
  endtask

  function automatic int ur(input int lo, input int hi);
    int span;
    span = hi - lo + 1;
    return lo + int'((seed ^ $urandom()) % span);
  endfunction

  task automatic read_ram(input int word);
    logic [c_DATA_W-1:0] w;
    int base;
    w = '0;
    base = word * int'(g_WORD_BYTES);
    for (int i = 0; i < int'(g_WORD_BYTES); i++)
      w[c_DATA_W-1 - i*int'(g_BYTE_WIDTH) -: g_BYTE_WIDTH] = ram[base+i];
    rd_data = w;
  endtask

  task automatic expect_bytes(input int base, input int len);
    if ((base < 0) || (len < 1) || (base + len > c_BYTES))
      $fatal(1, "avst_ram_read_unaligned bad window %0d + %0d", base, len);
    exp_base.push_back(base);
    exp_len.push_back(len);
  endtask

  always @(posedge clk) begin : proc_collect
    int n;
    int idx;
    logic [g_BYTE_WIDTH-1:0] got;
    if (!reset && src_valid && src_ready) begin
      if (!cur_on) begin
        if (exp_len.size() == 0)
          fail("unexpected output");
        cur_base = exp_base.pop_front();
        cur_len  = exp_len.pop_front();
        cur_got  = 0;
        cur_on   = 1'b1;
      end
      n = int'(g_WORD_BYTES) - int'(src_empty);
      if ((n < 1) || (n > int'(g_WORD_BYTES)))
        fail("bad empty");
      for (int i = 0; i < n; i++) begin
        got = src_data[c_DATA_W-1 - i*int'(g_BYTE_WIDTH) -: g_BYTE_WIDTH];
        idx = cur_base + cur_got;
        if (cur_got >= cur_len)
          fail("extra byte");
        if (got !== ram[idx])
          $fatal(1, "avst_ram_read_unaligned b%0d w%0d d%0d byte %0d got %h exp %h",
                 g_BYTE_WIDTH, g_WORD_BYTES, g_RAM_DEPTH, idx, got, ram[idx]);
        cur_got++;
      end
      if (src_eop) begin
        if (cur_got != cur_len)
          $fatal(1, "avst_ram_read_unaligned length got %0d exp %0d", cur_got, cur_len);
        cur_on = 1'b0;
      end
    end
  end

  task automatic pulse_start();
    @(posedge clk);
    #1;
    rd_start = 1'b1;
    @(posedge clk);
    #1;
    rd_start = 1'b0;
  endtask

  task automatic simulate_and_verify(input string id, input bit add_bp);
    int addr;
    int skew;
    int nwords;
    int cnt;
    int guard;
    bit do_read;
    pulse_start();
    addr   = int'(start_addr) / int'(g_WORD_BYTES);
    skew   = int'(start_addr) % int'(g_WORD_BYTES);
    nwords = (int'(rd_length) + skew + int'(g_WORD_BYTES) - 1) / int'(g_WORD_BYTES);
    cnt    = 0;
    while (cnt < nwords) begin
      #1;
      if (!back_pressure) begin
        if (!rd_busy)
          $fatal(1, "%s: not busy", id);
        if (!rd_en)
          $fatal(1, "%s: read enable low at %0d", id, cnt);
        if (int'(rd_addr) != addr)
          $fatal(1, "%s: addr got %0d exp %0d", id, rd_addr, addr);
      end else begin
        if (!rd_busy)
          $fatal(1, "%s: not busy during backpressure", id);
        if (rd_en)
          $fatal(1, "%s: read enable during backpressure", id);
      end
      if (add_bp && (cnt > 3) && (cnt < nwords - 1))
        back_pressure = 1'(ur(0, 1));
      else
        back_pressure = 1'b0;
      do_read = rd_en;
      @(posedge clk);
      #1;
      if (do_read) begin
        read_ram(addr);
        addr++;
        cnt++;
      end
    end
    #1;
    if (rd_en)
      $fatal(1, "%s: read did not stop", id);
    repeat (3) @(posedge clk);
    #1;
    if (rd_busy)
      $fatal(1, "%s: still busy", id);
    guard = 0;
    while ((exp_len.size() != 0) || cur_on) begin
      @(posedge clk);
      guard++;
      if (guard > nwords * 8 + 200)
        $fatal(1, "%s: output timeout", id);
    end
  endtask

  task automatic await_outputs(input int limit);
    int guard;
    guard = 0;
    while ((exp_len.size() != 0) || cur_on) begin
      @(posedge clk);
      guard++;
      if (guard > limit)
        fail("queued output timeout");
    end
  endtask

  initial begin : proc_seq
    int half;
    int iaddr;
    int ilen;
    done = 1'b0;
    cur_on = 1'b0;
    seed = 32'h0001_0002 + g_BYTE_WIDTH * 64 + g_WORD_BYTES * 8 + g_RAM_DEPTH;
    half = int'(g_RAM_DEPTH) / 2;
    void'($urandom(seed));
    for (int i = 0; i < c_BYTES; i++)
      ram[i] = g_BYTE_WIDTH'($urandom());

    repeat (3) @(posedge clk);
    #1;
    reset = 1'b0;
    @(posedge clk);
    #1;
    if (rd_en || rd_busy)
      fail("active after reset");
    repeat (4) begin
      @(posedge clk);
      #1;
      if (rd_en || rd_busy)
        fail("active while idle");
    end

    for (int i = 0; i < int'(g_WORD_BYTES); i++) begin
      iaddr = ur(0, half) * int'(g_WORD_BYTES) + i;
      ilen  = half * int'(g_WORD_BYTES) - i;
      start_addr = c_BADDR_W'(iaddr);
      rd_length  = c_LEN_W'(ilen);
      expect_bytes(iaddr, ilen);
      simulate_and_verify("multi", 1'b0);
    end

    for (int i = 5; i >= 1; i--) begin
      iaddr = ur(0, half) * int'(g_WORD_BYTES);
      ilen  = i * int'(g_WORD_BYTES);
      start_addr = c_BADDR_W'(iaddr);
      rd_length  = c_LEN_W'(ilen);
      expect_bytes(iaddr, ilen);
      simulate_and_verify("short aligned", 1'b0);
    end

    iaddr = ur(0, half) * int'(g_WORD_BYTES) + 1;
    ilen  = int'(g_WORD_BYTES) - 1;
    start_addr = c_BADDR_W'(iaddr);
    rd_length  = c_LEN_W'(ilen);
    expect_bytes(iaddr, ilen);
    simulate_and_verify("single 1", 1'b0);

    iaddr = ur(1, half) * int'(g_WORD_BYTES) - 1;
    ilen  = 2;
    start_addr = c_BADDR_W'(iaddr);
    rd_length  = c_LEN_W'(ilen);
    expect_bytes(iaddr, ilen);
    simulate_and_verify("single 2", 1'b0);

    for (int i = 2; i <= 5; i++) begin
      iaddr = ur(1, half) * int'(g_WORD_BYTES) - 1;
      ilen  = (i - 1) * int'(g_WORD_BYTES) + 1;
      start_addr = c_BADDR_W'(iaddr);
      rd_length  = c_LEN_W'(ilen);
      expect_bytes(iaddr, ilen);
      simulate_and_verify("short unaligned add", 1'b0);

      iaddr = ur(0, half) * int'(g_WORD_BYTES) + 1;
      ilen  = i * int'(g_WORD_BYTES) - 1;
      start_addr = c_BADDR_W'(iaddr);
      rd_length  = c_LEN_W'(ilen);
      expect_bytes(iaddr, ilen);
      simulate_and_verify("short unaligned", 1'b0);
    end

    start_addr = '0;
    rd_length  = c_LEN_W'(c_BYTES);
    expect_bytes(0, c_BYTES);
    simulate_and_verify("max", 1'b0);

    start_addr = '0;
    rd_length  = c_LEN_W'(c_BYTES);
    expect_bytes(0, c_BYTES);
    simulate_and_verify("backpressure", 1'b1);

    // Edge cases: hold the output, then release it a beat at a time.
    back_pressure = 1'b0;
    iaddr = 1;
    ilen  = 1;
    start_addr = c_BADDR_W'(iaddr);
    rd_length  = c_LEN_W'(ilen);
    expect_bytes(iaddr, ilen);
    pulse_start();
    back_pressure = 1'b1;
    #1;
    if (!rd_en)
      fail("7a read enable");
    @(posedge clk);
    #1;
    read_ram(0);
    @(posedge clk);
    #1;
    rd_data = '0;
    begin
      int guard;
      guard = 0;
      while (rd_busy) begin
        @(posedge clk);
        guard++;
        if (guard > 20)
          fail("7a busy");
      end
    end

    iaddr = int'(g_WORD_BYTES) - 1;
    ilen  = 2;
    start_addr = c_BADDR_W'(iaddr);
    rd_length  = c_LEN_W'(ilen);
    expect_bytes(iaddr, ilen);
    pulse_start();
    #1;
    if (!rd_en)
      fail("7b read enable");
    @(posedge clk);
    #1;
    read_ram(0);
    @(posedge clk);
    #1;
    read_ram(1);
    @(posedge clk);
    #1;
    rd_data = '0;
    repeat (5) @(posedge clk);
    #1;
    back_pressure = 1'b0;
    @(posedge clk);
    #1;
    back_pressure = 1'b1;

    iaddr = int'(g_WORD_BYTES) - 1;
    ilen  = 2 * int'(g_WORD_BYTES) - 1;
    start_addr = c_BADDR_W'(iaddr);
    rd_length  = c_LEN_W'(ilen);
    expect_bytes(iaddr, ilen);
    pulse_start();
    #1;
    if (!rd_en)
      fail("7c read enable");
    @(posedge clk);
    #1;
    read_ram(0);
    @(posedge clk);
    #1;
    read_ram(1);
    @(posedge clk);
    #1;
    read_ram(2);
    @(posedge clk);
    #1;
    rd_data = '0;
    repeat (5) @(posedge clk);
    #1;
    back_pressure = 1'b0;
    @(posedge clk);
    #1;
    back_pressure = 1'b1;
    repeat (5) @(posedge clk);
    #1;
    back_pressure = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    back_pressure = 1'b1;
    #1;
    if (rd_busy)
      fail("7c still busy");

    iaddr = int'(g_WORD_BYTES) + 1;
    ilen  = 3 * int'(g_WORD_BYTES) - 2;
    start_addr = c_BADDR_W'(iaddr);
    rd_length  = c_LEN_W'(ilen);
    expect_bytes(iaddr, ilen);
    pulse_start();
    #1;
    if (!rd_en)
      fail("7d read enable");
    @(posedge clk);
    #1;
    read_ram(1);
    @(posedge clk);
    #1;
    read_ram(2);
    @(posedge clk);
    #1;
    read_ram(3);
    @(posedge clk);
    #1;
    rd_data = '0;
    repeat (5) @(posedge clk);
    #1;
    back_pressure = 1'b0;
    await_outputs(4000);
    repeat (4) @(posedge clk);
    done = 1'b1;
  end

endmodule

module avst_ram_read_unaligned_tb;
  logic [11:0] done;

  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(2), .g_RAM_DEPTH(17))  u0 (.done(done[0]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(2), .g_RAM_DEPTH(128)) u1 (.done(done[1]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(5), .g_RAM_DEPTH(17))  u2 (.done(done[2]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(5), .g_RAM_DEPTH(128)) u3 (.done(done[3]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(8), .g_RAM_DEPTH(17))  u4 (.done(done[4]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(8), .g_RAM_DEPTH(128)) u5 (.done(done[5]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(2), .g_RAM_DEPTH(17))  u6 (.done(done[6]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(2), .g_RAM_DEPTH(128)) u7 (.done(done[7]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(5), .g_RAM_DEPTH(17))  u8 (.done(done[8]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(5), .g_RAM_DEPTH(128)) u9 (.done(done[9]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(8), .g_RAM_DEPTH(17))  u10 (.done(done[10]));
  avst_ram_read_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(8), .g_RAM_DEPTH(128)) u11 (.done(done[11]));

  initial begin
    wait (&done);
    $display("avst_ram_read_unaligned_tb PASS");
    $finish;
  end
  initial begin
    #20ms;
    $fatal(1, "avst_ram_read_unaligned_tb watchdog");
  end
endmodule
