// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Unaligned Avalon-ST RAM writer. Same directed cases as the VHDL testbench:
// sop, body, pause, eop, back-to-back short packets, single-beat packets,
// aligned bursts, and flush. Byte width 8 or 9, word size 2, 5, or 8.
module avst_ram_write_unaligned_harness #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 100,
  localparam int c_DATA_W  = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_BYTES   = int'(g_RAM_DEPTH) * int'(g_WORD_BYTES),
  localparam int c_BADDR_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_BYTES)),
  localparam int c_ADDR_W  = colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_RAM_DEPTH)))
) (
  output logic done
);

  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic [c_DATA_W-1:0]     snk_data = '0;
  logic [c_EMPTY_W-1:0]    snk_empty = '0;
  logic                    snk_sop = 1'b0;
  logic                    snk_eop = 1'b0;
  logic                    snk_valid = 1'b0;
  logic                    snk_ready;
  logic [c_BADDR_W-1:0]    start_addr = '0;
  logic                    flush = 1'b0;
  logic [g_WORD_BYTES-1:0] wr_be;
  logic [c_ADDR_W-1:0]     wr_addr;
  logic [c_DATA_W-1:0]     wr_data;

  logic [c_DATA_W-1:0]     data_q [$];
  logic [c_BADDR_W-1:0]    addr_q [$];
  logic [c_EMPTY_W-1:0]    empty_q [$];
  int unsigned             seed;
  int                      checks;

  always #5 clk = ~clk;

  avst_ram_write_unaligned #(
    .g_BYTE_WIDTH (g_BYTE_WIDTH),
    .g_WORD_BYTES (g_WORD_BYTES),
    .g_RAM_DEPTH  (g_RAM_DEPTH)
  ) dut (
    .clk_i        (clk),
    .reset_i      (reset),
    .snk_data_i   (snk_data),
    .snk_empty_i  (snk_empty),
    .snk_sop_i    (snk_sop),
    .snk_eop_i    (snk_eop),
    .snk_valid_i  (snk_valid),
    .snk_ready_o  (snk_ready),
    .start_addr_i (start_addr),
    .flush_i      (flush),
    .wr_be_o      (wr_be),
    .wr_addr_o    (wr_addr),
    .wr_data_o    (wr_data)
  );

  function automatic int ur(input int lo, input int hi);
    int unsigned mix;
    mix = seed ^ $urandom();
    return lo + int'(mix % (hi - lo + 1));
  endfunction

  function automatic logic [c_DATA_W-1:0] rand_word();
    logic [c_DATA_W-1:0] w;
    w = '0;
    for (int i = 0; i < int'(g_WORD_BYTES); i++)
      w[i*int'(g_BYTE_WIDTH) +: g_BYTE_WIDTH] = g_BYTE_WIDTH'($urandom());
    return w;
  endfunction

  task automatic fail(input string msg);
    $fatal(1, "avst_ram_write_unaligned b%0d w%0d: %s", g_BYTE_WIDTH, g_WORD_BYTES, msg);
  endtask

  task automatic progress_data();
    snk_data = rand_word();
    @(posedge clk);
    data_q.push_back(snk_data);
    #1;
  endtask

  task automatic edges(input int n);
    repeat (n) @(posedge clk);
    #1;
  endtask

  function automatic logic [g_BYTE_WIDTH-1:0] byte_at(
    input logic [c_DATA_W-1:0] word,
    input int                  index
  );
    return word[c_DATA_W-1 - index*int'(g_BYTE_WIDTH) -: g_BYTE_WIDTH];
  endfunction

  function automatic logic [c_DATA_W-1:0] pack_byte(
    input logic [c_DATA_W-1:0] word,
    input int                  index,
    input logic [g_BYTE_WIDTH-1:0] b
  );
    logic [c_DATA_W-1:0] w;
    w = word;
    w[c_DATA_W-1 - index*int'(g_BYTE_WIDTH) -: g_BYTE_WIDTH] = b;
    return w;
  endfunction

  task automatic check_ram(input int skew, input logic [c_ADDR_W-1:0] addr,
                           input logic [g_WORD_BYTES-1:0] mask, input string id);
    logic [c_DATA_W-1:0] prev;
    logic [c_DATA_W-1:0] nxt;
    logic [c_DATA_W-1:0] exp;
    if (data_q.size() < 2)
      $fatal(1, "%s: scoreboard empty", id);
    prev = data_q.pop_front();
    nxt  = data_q[0];
    exp  = '0;
    for (int i = 0; i < skew; i++)
      exp = pack_byte(exp, i, byte_at(prev, int'(g_WORD_BYTES) - skew + i));
    for (int i = skew; i < int'(g_WORD_BYTES); i++)
      exp = pack_byte(exp, i, byte_at(nxt, i - skew));
    if (wr_be !== mask)
      $fatal(1, "%s: be got %b exp %b", id, wr_be, mask);
    if (wr_addr !== addr)
      $fatal(1, "%s: addr got %0d exp %0d", id, wr_addr, addr);
    if (wr_data !== exp)
      $fatal(1, "%s: data got %h exp %h", id, wr_data, exp);
    checks++;
  endtask

  function automatic logic [g_WORD_BYTES-1:0] mask_ge(input int skew);
    logic [g_WORD_BYTES-1:0] m;
    for (int i = 0; i < int'(g_WORD_BYTES); i++)
      m[int'(g_WORD_BYTES)-1-i] = (i >= skew);
    return m;
  endfunction

  function automatic logic [g_WORD_BYTES-1:0] mask_lt(input int limit);
    logic [g_WORD_BYTES-1:0] m;
    for (int i = 0; i < int'(g_WORD_BYTES); i++)
      m[int'(g_WORD_BYTES)-1-i] = (i < limit);
    return m;
  endfunction

  function automatic logic [g_WORD_BYTES-1:0] mask_range(input int lo, input int hi);
    logic [g_WORD_BYTES-1:0] m;
    for (int i = 0; i < int'(g_WORD_BYTES); i++)
      m[int'(g_WORD_BYTES)-1-i] = (i >= lo) && (i < hi);
    return m;
  endfunction

  initial begin : proc_driver
    int skew_i;
    seed = 32'h5755_0000 + g_BYTE_WIDTH + (g_WORD_BYTES << 4);
    wait (reset == 1'b0);
    repeat (3) @(posedge clk);
    #1;

    start_addr = c_BADDR_W'(ur(0, int'(g_RAM_DEPTH)) * int'(g_WORD_BYTES)
                            + ur(1, int'(g_WORD_BYTES) - 1));
    snk_valid = 1'b1;
    snk_sop   = 1'b1;
    addr_q.push_back(start_addr);
    progress_data();
    snk_sop = 1'b0;

    for (int i = 0; i < 3; i++)
      progress_data();

    snk_valid = 1'b0;
    @(posedge clk);
    #1;

    skew_i = int'(start_addr) % int'(g_WORD_BYTES);
    snk_valid = 1'b1;
    snk_eop   = 1'b1;
    snk_empty = c_EMPTY_W'(ur(0, skew_i - 1));
    empty_q.push_back(snk_empty);
    progress_data();
    data_q.push_back('0);
    snk_eop   = 1'b0;
    snk_empty = '0;

    start_addr = c_BADDR_W'(ur(0, int'(g_RAM_DEPTH)) * int'(g_WORD_BYTES) + 1);
    snk_sop = 1'b1;
    addr_q.push_back(start_addr);
    progress_data();
    @(posedge clk);
    while (!snk_ready) @(posedge clk);
    #1;
    snk_sop = 1'b0;
    snk_eop = 1'b1;
    snk_empty = c_EMPTY_W'(int'(g_WORD_BYTES) - 1);
    progress_data();
    snk_valid = 1'b0;
    snk_eop   = 1'b0;
    snk_empty = '0;

    repeat (5) @(posedge clk);
    #1;

    snk_sop   = 1'b1;
    snk_eop   = 1'b1;
    snk_valid = 1'b1;
    for (int i = 1; i <= int'(g_WORD_BYTES); i++) begin
      start_addr = c_BADDR_W'(ur(0, int'(g_RAM_DEPTH)) * int'(g_WORD_BYTES)
                              + (i % int'(g_WORD_BYTES)));
      snk_empty = c_EMPTY_W'(int'(g_WORD_BYTES) - i);
      addr_q.push_back(start_addr);
      progress_data();
      if ((2 * i > int'(g_WORD_BYTES)) && (i < int'(g_WORD_BYTES))) begin
        data_q.push_back('0);
        #1;
        if (snk_ready !== 1'b0)
          fail("ready should fall after a wide single-beat packet");
        @(posedge clk);
        #1;
        if (snk_ready !== 1'b1)
          fail("ready should return after a wide single-beat packet");
      end
    end
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
    snk_valid = 1'b0;
    snk_empty = '0;

    repeat (5) @(posedge clk);
    #1;
    for (int packet = 0; packet < 2; packet++) begin
      start_addr = c_BADDR_W'(ur(0, int'(g_RAM_DEPTH)) * int'(g_WORD_BYTES));
      snk_sop   = 1'b1;
      snk_valid = 1'b1;
      addr_q.push_back(start_addr);
      progress_data();
      snk_sop = 1'b0;
      for (int i = 0; i < 3 * int'(g_RAM_DEPTH); i++) begin
        progress_data();
        start_addr = c_BADDR_W'($urandom());
        snk_sop = 1'($urandom_range(1, 0));
      end
      snk_eop = 1'b1;
      snk_sop = 1'b0;
      progress_data();
      snk_eop   = 1'b0;
      snk_valid = 1'b0;
    end

    repeat (5) @(posedge clk);
    #1;
    for (int packet = 0; packet < 2; packet++) begin
      start_addr = c_BADDR_W'(ur(0, int'(g_RAM_DEPTH)) * int'(g_WORD_BYTES)
                              + ur(1, int'(g_WORD_BYTES) - 1));
      snk_sop   = 1'b1;
      snk_valid = 1'b1;
      addr_q.push_back(start_addr);
      progress_data();
      snk_sop = 1'b0;
      for (int i = 0; i < 3; i++)
        progress_data();
      data_q.push_back('0);
      snk_valid = 1'b0;
      flush = 1'b1;
      @(posedge clk);
      #1;
      flush = 1'b0;
    end

    repeat (30) @(posedge clk);
  end

  initial begin : proc_check
    int                    skew;
    int                    empty_i;
    logic [c_ADDR_W-1:0]   addr;
    logic [g_WORD_BYTES-1:0] mask;
    checks = 0;
    data_q.push_back('0);
    repeat (3) @(posedge clk);
    #1;
    if (snk_ready !== 1'b0)
      fail("ready high during reset");
    reset = 1'b0;
    @(posedge clk);
    #1;
    if (snk_ready !== 1'b1)
      fail("ready should rise after reset");
    if (|wr_be)
      fail("write active without data");

    wait (snk_valid == 1'b1);
    edges(2);
    addr = c_ADDR_W'(int'(addr_q[0]) / int'(g_WORD_BYTES));
    skew = int'(addr_q.pop_front()) % int'(g_WORD_BYTES);
    check_ram(skew, addr, mask_ge(skew), "TEST 1");

    mask = {g_WORD_BYTES{1'b1}};
    for (int i = 1; i <= 3; i++) begin
      addr = addr + c_ADDR_W'(1);
      edges(1);
      check_ram(skew, addr, mask, "TEST 2");
    end

    edges(1);
    if (|wr_be)
      fail("TEST 3 write while paused");

    #1;
    if (snk_ready !== 1'b0)
      fail("TEST 4 ready should fall after eop");
    edges(1);
    if (snk_ready !== 1'b1)
      fail("TEST 4 ready should return");
    addr = addr + c_ADDR_W'(1);
    check_ram(skew, addr, mask, "TEST 4a");

    edges(1);
    empty_i = int'(empty_q.pop_front());
    check_ram(skew, addr + c_ADDR_W'(1), mask_lt(skew - empty_i), "TEST 4b");
    addr = addr + c_ADDR_W'(1);

    skew = 1;
    addr = c_ADDR_W'(int'(addr_q.pop_front()) / int'(g_WORD_BYTES));
    edges(1);
    check_ram(skew, addr, mask_ge(skew), "TEST 5a");
    if (snk_ready !== 1'b1)
      fail("TEST 5 ready should stay high");
    empty_i = int'(g_WORD_BYTES) - 1;
    addr = addr + c_ADDR_W'(1);
    edges(1);
    check_ram(skew, addr, mask_lt(skew + int'(g_WORD_BYTES) - empty_i), "TEST 5b");

    edges(1);
    if (|wr_be)
      fail("TEST 6 write after eop");
    repeat (4) begin
      @(posedge clk);
      #1;
      if (|wr_be)
        fail("TEST 6 spontaneous write");
    end
    @(posedge clk);

    for (int i = 1; i < int'(g_WORD_BYTES); i++) begin
      addr = c_ADDR_W'(int'(addr_q.pop_front()) / int'(g_WORD_BYTES));
      skew = i;
      if ((2 * i) > int'(g_WORD_BYTES)) begin
        #1;
        check_ram(skew, addr, mask_ge(i), "TEST 7a");
        addr = addr + c_ADDR_W'(1);
        edges(1);
        check_ram(skew, addr, mask_lt(2 * i - int'(g_WORD_BYTES)), "TEST 7b");
      end else begin
        #1;
        check_ram(skew, addr, mask_range(i, 2 * i), "TEST 7");
      end
      @(posedge clk);
    end

    skew = 0;
    addr = c_ADDR_W'(int'(addr_q.pop_front()) / int'(g_WORD_BYTES));
    #1;
    check_ram(0, addr, {g_WORD_BYTES{1'b1}}, "TEST 7 full");

    wait (snk_valid == 1'b1);
    @(posedge clk);
    for (int packet = 0; packet < 2; packet++) begin
      addr = c_ADDR_W'(int'(addr_q.pop_front()) / int'(g_WORD_BYTES));
      mask = {g_WORD_BYTES{1'b1}};
      for (int i = 0; i <= 3 * int'(g_RAM_DEPTH); i++) begin
        edges(1);
        check_ram(0, addr, mask, "TEST 8");
        addr = addr + c_ADDR_W'(1);
      end
      edges(1);
      check_ram(0, addr, mask, "TEST 8 eop");
    end

    wait (snk_valid == 1'b1);
    @(posedge clk);
    for (int packet = 0; packet < 2; packet++) begin
      addr = c_ADDR_W'(int'(addr_q[0]) / int'(g_WORD_BYTES));
      skew = int'(addr_q.pop_front()) % int'(g_WORD_BYTES);
      mask = mask_ge(skew);
      for (int i = 0; i <= 3; i++) begin
        edges(1);
        check_ram(skew, addr, mask, "TEST 9");
        addr = addr + c_ADDR_W'(1);
        mask = {g_WORD_BYTES{1'b1}};
      end
      edges(1);
      check_ram(skew, addr, mask_lt(skew), "TEST 9 flush");
    end
    @(posedge clk);
    done = 1'b1;
  end

endmodule

module avst_ram_write_unaligned_tb;
  logic [5:0] done;
  avst_ram_write_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(2)) u0 (.done(done[0]));
  avst_ram_write_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(5)) u1 (.done(done[1]));
  avst_ram_write_unaligned_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(8)) u2 (.done(done[2]));
  avst_ram_write_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(2)) u3 (.done(done[3]));
  avst_ram_write_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(5)) u4 (.done(done[4]));
  avst_ram_write_unaligned_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(8)) u5 (.done(done[5]));

  initial begin
    wait (&done);
    $display("avst_ram_write_unaligned_tb PASS");
    $finish;
  end
  initial begin
    #20ms;
    $fatal(1, "avst_ram_write_unaligned_tb watchdog");
  end
endmodule
