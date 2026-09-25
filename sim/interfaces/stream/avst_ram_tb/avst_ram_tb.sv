// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Write four quarters of a dual-port RAM out of order, then read the whole
// RAM three times. Configurations match run.py: data 8 and 64, address 3, 5, 7.
module avst_ram_harness #(
  parameter int unsigned g_DATA_WIDTH = 32,
  parameter int unsigned g_ADDR_WIDTH = 8,
  localparam int c_WORDS     = 1 << g_ADDR_WIDTH,
  localparam int c_WORD_BYTES = int'(g_DATA_WIDTH) / 8,
  localparam int c_MEM_BYTES = c_WORDS * c_WORD_BYTES,
  localparam int c_LEN_W     = colibri_utils::log2ceil(c_MEM_BYTES + 1),
  localparam int c_CHUNK     = c_WORDS / 4
) (
  output logic done
);

  logic                        wr_clk = 1'b0;
  logic                        rd_clk = 1'b0;
  logic                        reset_a = 1'b0;
  logic                        wr_reset;
  logic                        rd_reset;
  logic                        wr_en;
  logic [g_ADDR_WIDTH-1:0]     wr_addr;
  logic [g_DATA_WIDTH-1:0]     wr_data;
  logic                        rd_en;
  logic [g_ADDR_WIDTH-1:0]     rd_addr_ram;
  logic [g_DATA_WIDTH-1:0]     rd_data;
  logic [g_ADDR_WIDTH-1:0]     start_addr = '0;
  logic                        snk_sop = 1'b0;
  logic                        snk_eop = 1'b0;
  logic [g_DATA_WIDTH-1:0]     snk_data = '0;
  logic                        snk_valid = 1'b0;
  logic [g_DATA_WIDTH-1:0]     src_data;
  logic [colibri_types::avst_empty_width(int'(g_DATA_WIDTH), 8)-1:0] src_empty;
  logic                        src_sop;
  logic                        src_eop;
  logic                        src_valid;
  logic                        src_ready = 1'b1;
  logic [g_ADDR_WIDTH-1:0]     rd_start_addr = '0;
  logic [c_LEN_W-1:0]          rd_length = '0;
  logic                        rd_start = 1'b0;
  logic                        rd_stop = 1'b0;
  logic                        busy;

  logic [g_DATA_WIDTH-1:0] mem [0:c_WORDS-1];
  int                      words_got;
  int unsigned             seed;

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

  avst_ram_write #(
    .g_DATA_WIDTH (g_DATA_WIDTH),
    .g_ADDR_WIDTH (g_ADDR_WIDTH)
  ) uut_write (
    .clk_i        (wr_clk),
    .reset_i      (wr_reset),
    .start_addr_i (start_addr),
    .snk_sop_i    (snk_sop),
    .snk_eop_i    (snk_eop),
    .snk_data_i   (snk_data),
    .snk_valid_i  (snk_valid),
    .wr_en_o      (wr_en),
    .wr_addr_o    (wr_addr),
    .wr_data_o    (wr_data)
  );

  simple_dpram #(
    .g_DATA_WIDTH (g_DATA_WIDTH),
    .g_N_WORDS    (c_WORDS)
  ) u_ram (
    .wrclk_i  (wr_clk),
    .wren_i   (wr_en),
    .wraddr_i (wr_addr),
    .wrdata_i (wr_data),
    .rdclk_i  (rd_clk),
    .rden_i   (rd_en),
    .rdaddr_i (rd_addr_ram),
    .rddata_o (rd_data)
  );

  avst_ram_read #(
    .g_BYTE_WIDTH (8),
    .g_WORD_BYTES (c_WORD_BYTES),
    .g_RAM_DEPTH  (c_WORDS)
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
    .stop_i       (rd_stop),
    .busy_o       (busy),
    .rd_en_o      (rd_en),
    .rd_addr_o    (rd_addr_ram),
    .rd_data_i    (rd_data)
  );

  always @(posedge rd_clk) begin : proc_collect
    if (!rd_reset && src_valid && src_ready) begin
      if (words_got == 0 && !src_sop)
        $fatal(1, "avst_ram d%0d a%0d missing sop", g_DATA_WIDTH, g_ADDR_WIDTH);
      if (words_got >= c_WORDS)
        $fatal(1, "avst_ram d%0d a%0d extra word", g_DATA_WIDTH, g_ADDR_WIDTH);
      if (src_data !== mem[words_got])
        $fatal(1, "avst_ram d%0d a%0d word %0d got %h exp %h",
               g_DATA_WIDTH, g_ADDR_WIDTH, words_got, src_data, mem[words_got]);
      if (src_empty != '0)
        $fatal(1, "avst_ram d%0d a%0d empty %0d", g_DATA_WIDTH, g_ADDR_WIDTH, src_empty);
      words_got++;
    end
  end

  initial begin : proc_seq
    int seq [0:3];
    int base;
    int guard;
    done      = 1'b0;
    words_got = 0;
    seed      = 32'hA100_0000 + g_DATA_WIDTH + g_ADDR_WIDTH;
    seq[0] = 2;
    seq[1] = 1;
    seq[2] = 3;
    seq[3] = 0;
    for (int i = 0; i < c_WORDS; i++)
      mem[i] = g_DATA_WIDTH'($urandom(seed));

    #1;
    reset_a = 1'b1;
    repeat (6) @(posedge wr_clk);
    reset_a = 1'b0;
    wait ((wr_reset == 1'b0) && (rd_reset == 1'b0));
    repeat (2) @(posedge wr_clk);

    for (int i = 0; i < 4; i++) begin
      base = seq[i] * c_CHUNK;
      #1;
      start_addr = g_ADDR_WIDTH'(base);
      for (int w = 0; w < c_CHUNK; w++) begin
        snk_valid = 1'b1;
        snk_sop   = (w == 0);
        snk_eop   = (w == c_CHUNK - 1);
        snk_data  = mem[base + w];
        @(posedge wr_clk);
        #1;
      end
      snk_valid = 1'b0;
      snk_sop   = 1'b0;
      snk_eop   = 1'b0;
      @(posedge wr_clk);
      if (i == 0)
        repeat (10) @(posedge wr_clk);
    end
    repeat (4) @(posedge wr_clk);

    #1;
    rd_start_addr = '0;
    rd_length     = c_LEN_W'(c_MEM_BYTES);
    for (int pass = 0; pass < 3; pass++) begin
      words_got = 0;
      @(posedge rd_clk);
      #1;
      rd_start = 1'b1;
      @(posedge rd_clk);
      #1;
      rd_start = 1'b0;
      guard = 0;
      while (words_got != c_WORDS) begin
        @(posedge rd_clk);
        guard++;
        if (guard > c_WORDS * 8 + 100)
          $fatal(1, "avst_ram d%0d a%0d read timeout pass %0d got %0d",
                 g_DATA_WIDTH, g_ADDR_WIDTH, pass, words_got);
      end
      guard = 0;
      while (busy) begin
        @(posedge rd_clk);
        guard++;
        if (guard > 100)
          $fatal(1, "avst_ram d%0d a%0d busy stuck", g_DATA_WIDTH, g_ADDR_WIDTH);
      end
      repeat (3) @(posedge rd_clk);
    end
    done = 1'b1;
  end

endmodule

module avst_ram_tb;
  logic [5:0] done;
  initial begin
    wait (&done);
    $display("avst_ram_tb PASS");
    $finish;
  end
  initial begin
    #5ms;
    $fatal(1, "avst_ram_tb watchdog");
  end

  avst_ram_harness #(.g_DATA_WIDTH(8),  .g_ADDR_WIDTH(3)) u0 (.done(done[0]));
  avst_ram_harness #(.g_DATA_WIDTH(64), .g_ADDR_WIDTH(3)) u1 (.done(done[1]));
  avst_ram_harness #(.g_DATA_WIDTH(8),  .g_ADDR_WIDTH(5)) u2 (.done(done[2]));
  avst_ram_harness #(.g_DATA_WIDTH(64), .g_ADDR_WIDTH(5)) u3 (.done(done[3]));
  avst_ram_harness #(.g_DATA_WIDTH(8),  .g_ADDR_WIDTH(7)) u4 (.done(done[4]));
  avst_ram_harness #(.g_DATA_WIDTH(64), .g_ADDR_WIDTH(7)) u5 (.done(done[5]));
endmodule
