// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Unaligned Avalon-ST RAM write and read through a byte-enabled dual-port RAM.
// Eight write packets fill the RAM (last packet first). Seven read packets
// check the bytes. Byte width 8 or 9, words of 1, 2, 5, or 8 bytes.
module avst_ram_be_harness #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  parameter int unsigned g_WORD_BYTES = 4,
  localparam int c_N_BYTES = 256 - (256 % int'(g_WORD_BYTES)),
  localparam int c_N_WORDS = c_N_BYTES / int'(g_WORD_BYTES),
  localparam int c_DATA_W  = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_BADDR_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_N_BYTES)),
  localparam int c_ADDR_W  = colibri_utils::downto_width(colibri_utils::log2ceil(c_N_WORDS)),
  localparam int c_LEN_W   = colibri_utils::log2ceil(c_N_BYTES) + 1,
  localparam int c_N_WR    = 8,
  localparam int c_N_RD    = 7
) (
  output logic done
);

  logic                     wr_clk = 1'b0;
  logic                     rd_clk = 1'b0;
  logic                     reset_a = 1'b0;
  logic                     wr_reset;
  logic                     rd_reset;
  logic                     snk_ready;
  logic                     snk_valid = 1'b0;
  logic                     snk_sop = 1'b0;
  logic                     snk_eop = 1'b0;
  logic [c_EMPTY_W-1:0]     snk_empty = '0;
  logic [c_DATA_W-1:0]      snk_data = '0;
  logic [c_BADDR_W-1:0]     wr_start = '0;
  logic [g_WORD_BYTES-1:0]  wr_be;
  logic [c_ADDR_W-1:0]      wr_addr;
  logic [c_DATA_W-1:0]      wr_data;
  logic                     rd_en;
  logic [c_ADDR_W-1:0]      rd_addr;
  logic [c_DATA_W-1:0]      rd_data;
  logic [c_DATA_W-1:0]      src_data;
  logic [c_EMPTY_W-1:0]     src_empty;
  logic                     src_sop;
  logic                     src_eop;
  logic                     src_valid;
  logic                     src_ready = 1'b1;
  logic [c_BADDR_W-1:0]     rd_start_addr = '0;
  logic [c_LEN_W-1:0]       rd_length = '0;
  logic                     rd_start = 1'b0;
  logic                     rd_busy;

  logic [g_BYTE_WIDTH-1:0] ram_bytes [0:c_N_BYTES-1];
  int                      wr_addr_q [0:c_N_WR-1];
  int                      wr_size_q [0:c_N_WR-1];
  int                      rd_addr_q [0:c_N_RD-1];
  int                      rd_size_q [0:c_N_RD-1];
  int                      got_n;
  int                      exp_base;
  int                      exp_len;
  bit                      collecting;

  always #4 wr_clk = ~wr_clk;
  always #5 rd_clk = ~rd_clk;

  synchro_reset wr_synchro_reset (
    .clk_i   (wr_clk),
    .reset_i (reset_a),
    .reset_o (wr_reset)
  );
  synchro_reset rd_synchro_reset (
    .clk_i   (rd_clk),
    .reset_i (reset_a),
    .reset_o (rd_reset)
  );

  avst_ram_write_unaligned #(
    .g_BYTE_WIDTH (g_BYTE_WIDTH),
    .g_WORD_BYTES (g_WORD_BYTES),
    .g_RAM_DEPTH  (c_N_WORDS)
  ) uut_write (
    .clk_i        (wr_clk),
    .reset_i      (wr_reset),
    .snk_data_i   (snk_data),
    .snk_empty_i  (snk_empty),
    .snk_sop_i    (snk_sop),
    .snk_eop_i    (snk_eop),
    .snk_valid_i  (snk_valid),
    .snk_ready_o  (snk_ready),
    .start_addr_i (wr_start),
    .flush_i      (1'b0),
    .wr_be_o      (wr_be),
    .wr_addr_o    (wr_addr),
    .wr_data_o    (wr_data)
  );

  simple_dpram_be #(
    .g_BYTE_WIDTH (g_BYTE_WIDTH),
    .g_WORD_BYTES (g_WORD_BYTES),
    .g_N_WORDS    (c_N_WORDS)
  ) u_ram (
    .wrclk_i  (wr_clk),
    .wren_i   (wr_be),
    .wraddr_i (wr_addr),
    .wrdata_i (wr_data),
    .rdclk_i  (rd_clk),
    .rden_i   (rd_en),
    .rdaddr_i (rd_addr),
    .rddata_o (rd_data)
  );

  avst_ram_read_unaligned #(
    .g_BYTE_WIDTH (g_BYTE_WIDTH),
    .g_WORD_BYTES (g_WORD_BYTES),
    .g_RAM_DEPTH  (c_N_WORDS)
  ) uut_read (
    .clk_i        (rd_clk),
    .reset_i      (rd_reset),
    .src_data_o   (src_data),
    .src_empty_o  (src_empty),
    .src_sop_o    (src_sop),
    .src_eop_o    (src_eop),
    .src_valid_o  (src_valid),
    .src_ready_i  (src_ready),
    .start_addr_i (rd_start_addr),
    .length_i     (rd_length),
    .start_i      (rd_start),
    .busy_o       (rd_busy),
    .rd_en_o      (rd_en),
    .rd_addr_o    (rd_addr),
    .rd_data_i    (rd_data)
  );

  function automatic logic [c_DATA_W-1:0] pack_bytes(input int base, input int n);
    logic [c_DATA_W-1:0] w;
    w = '0;
    for (int i = 0; i < n; i++)
      w[c_DATA_W-1 - i*int'(g_BYTE_WIDTH) -: g_BYTE_WIDTH] = ram_bytes[base+i];
    return w;
  endfunction

  task automatic fail(input string msg);
    $fatal(1, "avst_ram_be b%0d w%0d: %s", g_BYTE_WIDTH, g_WORD_BYTES, msg);
  endtask

  always @(posedge rd_clk) begin : proc_collect
    int n;
    int idx;
    logic [g_BYTE_WIDTH-1:0] got;
    if (collecting && !rd_reset && src_valid && src_ready) begin
      n = int'(g_WORD_BYTES) - int'(src_empty);
      if ((n < 1) || (n > int'(g_WORD_BYTES)))
        fail("bad empty");
      for (int i = 0; i < n; i++) begin
        got = src_data[c_DATA_W-1 - i*int'(g_BYTE_WIDTH) -: g_BYTE_WIDTH];
        idx = exp_base + got_n;
        if (got_n >= exp_len)
          fail("extra read byte");
        if (got !== ram_bytes[idx])
          $fatal(1, "avst_ram_be b%0d w%0d byte %0d got %h exp %h",
                 g_BYTE_WIDTH, g_WORD_BYTES, idx, got, ram_bytes[idx]);
        got_n++;
      end
    end
  end

  task automatic drive_packet(input int base, input int nbytes);
    int left;
    int n;
    int guard;
    int sent;
    left = nbytes;
    sent = 0;
    wr_start = c_BADDR_W'(base);
    while (left > 0) begin
      n = int'(g_WORD_BYTES);
      if (n > left)
        n = left;
      #1;
      snk_valid = 1'b1;
      snk_sop   = (sent == 0);
      snk_eop   = (n == left);
      snk_empty = c_EMPTY_W'(int'(g_WORD_BYTES) - n);
      snk_data  = pack_bytes(base + sent, n);
      @(posedge wr_clk);
      guard = 0;
      while (!snk_ready) begin
        @(posedge wr_clk);
        guard++;
        if (guard > 10000)
          fail("write ready timeout");
      end
      sent += n;
      left -= n;
    end
    #1;
    snk_valid = 1'b0;
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
    snk_empty = '0;
    @(posedge wr_clk);
  endtask

  initial begin : proc_seq
    int unsigned useed;
    int avg;
    int addr;
    int sz;
    int guard;
    int rnd;
    done = 1'b0;
    collecting = 1'b0;
    useed = 32'hBEE0_0000 + g_BYTE_WIDTH * 16 + g_WORD_BYTES;
    for (int i = 0; i < c_N_BYTES; i++)
      ram_bytes[i] = g_BYTE_WIDTH'($urandom(useed));

    avg  = c_N_BYTES / c_N_WR;
    addr = 0;
    for (int i = 0; i < c_N_WR - 1; i++) begin
      rnd = (1 - avg) + int'($urandom(useed) % (avg + 1));
      sz  = avg + rnd;
      if (sz < 1)
        sz = 1;
      if ((addr + sz) > (c_N_BYTES - (c_N_WR - 1 - i)))
        sz = c_N_BYTES - (c_N_WR - 1 - i) - addr;
      wr_addr_q[i] = addr;
      wr_size_q[i] = sz;
      addr += sz;
    end
    wr_addr_q[c_N_WR-1] = addr;
    wr_size_q[c_N_WR-1] = c_N_BYTES - addr;

    avg  = c_N_BYTES / c_N_RD;
    addr = 0;
    for (int i = 0; i < c_N_RD - 1; i++) begin
      rnd = (1 - avg) + int'($urandom(useed) % (avg + 1));
      sz  = avg + rnd;
      if (sz < 1)
        sz = 1;
      if ((addr + sz) > (c_N_BYTES - (c_N_RD - 1 - i)))
        sz = c_N_BYTES - (c_N_RD - 1 - i) - addr;
      rd_addr_q[i] = addr;
      rd_size_q[i] = sz;
      addr += sz;
    end
    rd_addr_q[c_N_RD-1] = addr;
    rd_size_q[c_N_RD-1] = c_N_BYTES - addr;

    #1;
    reset_a = 1'b1;
    repeat (6) @(posedge wr_clk);
    reset_a = 1'b0;
    wait ((wr_reset == 1'b0) && (rd_reset == 1'b0));
    repeat (2) @(posedge wr_clk);

    for (int i = c_N_WR - 1; i >= 0; i--) begin
      drive_packet(wr_addr_q[i], wr_size_q[i]);
      if (i == 0)
        repeat (10) @(posedge wr_clk);
    end
    repeat (8) @(posedge wr_clk);

    for (int i = 0; i < c_N_RD; i++) begin
      guard = 0;
      while (rd_busy) begin
        @(posedge rd_clk);
        guard++;
        if (guard > c_N_WORDS * 4 + 50)
          fail("busy before read");
      end
      got_n    = 0;
      exp_base = rd_addr_q[i];
      exp_len  = rd_size_q[i];
      collecting = 1'b1;
      rd_start_addr = c_BADDR_W'(rd_addr_q[i]);
      rd_length     = c_LEN_W'(rd_size_q[i]);
      @(posedge rd_clk);
      #1;
      rd_start = 1'b1;
      @(posedge rd_clk);
      #1;
      rd_start = 1'b0;
      guard = 0;
      while (got_n != exp_len) begin
        @(posedge rd_clk);
        guard++;
        if (guard > c_N_BYTES * 4 + 200)
          $fatal(1, "avst_ram_be b%0d w%0d read %0d timeout got %0d/%0d",
                 g_BYTE_WIDTH, g_WORD_BYTES, i, got_n, exp_len);
      end
      collecting = 1'b0;
      repeat (2) @(posedge rd_clk);
    end
    done = 1'b1;
  end

endmodule

module avst_ram_be_tb;
  logic [7:0] done;
  avst_ram_be_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(1)) u0 (.done(done[0]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(2)) u1 (.done(done[1]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(5)) u2 (.done(done[2]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(8), .g_WORD_BYTES(8)) u3 (.done(done[3]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(1)) u4 (.done(done[4]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(2)) u5 (.done(done[5]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(5)) u6 (.done(done[6]));
  avst_ram_be_harness #(.g_BYTE_WIDTH(9), .g_WORD_BYTES(8)) u7 (.done(done[7]));

  initial begin
    wait (&done);
    $display("avst_ram_be_tb PASS");
    $finish;
  end
  initial begin
    #10ms;
    $fatal(1, "avst_ram_be_tb watchdog");
  end
endmodule
