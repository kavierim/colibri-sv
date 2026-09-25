// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Wishbone RAM. Random reads and writes until every word has been written
// and read. A shadow memory is the expected data.
module wb_ram_tb;
  localparam int c_N_WORDS = 16;
  localparam int c_DATA_W  = 32;
  localparam int c_ADDR_W  = 32;

  logic                  clk = 1'b0;
  logic                  reset = 1'b1;
  logic [c_ADDR_W-1:0]   wb_adr = '0;
  logic [c_DATA_W-1:0]   wb_dat_i = '0;
  logic [c_DATA_W-1:0]   wb_dat_o;
  logic                  wb_we = 1'b0;
  logic [c_DATA_W/8-1:0] wb_sel = '1;
  logic                  wb_stb = 1'b0;
  logic                  wb_cyc = 1'b0;
  logic                  wb_ack;
  logic                  wb_err;

  logic [c_DATA_W-1:0] shadow [0:c_N_WORDS-1];
  bit                  wr_hit [0:c_N_WORDS-1];
  bit                  rd_hit [0:c_N_WORDS-1];
  int unsigned         seed = 32'd32;

  always #2.5 clk = ~clk;

  wb_ram #(
    .g_N_WORDS       (c_N_WORDS),
    .g_WB_DATA_WIDTH (c_DATA_W),
    .g_WB_ADDR_WIDTH (c_ADDR_W)
  ) dut (
    .clk_i    (clk),
    .reset_i  (reset),
    .wb_adr_i (wb_adr),
    .wb_dat_i (wb_dat_i),
    .wb_dat_o (wb_dat_o),
    .wb_we_i  (wb_we),
    .wb_sel_i (wb_sel),
    .wb_stb_i (wb_stb),
    .wb_cyc_i (wb_cyc),
    .wb_ack_o (wb_ack),
    .wb_err_o (wb_err)
  );

  task automatic wb_cycle(input bit we, input int word, input logic [c_DATA_W-1:0] data,
                          output logic [c_DATA_W-1:0] rdata);
    int guard;
    @(posedge clk);
    #1;
    wb_cyc   = 1'b1;
    wb_stb   = 1'b1;
    wb_we    = we;
    wb_sel   = '1;
    wb_adr   = c_ADDR_W'(word * 4);
    wb_dat_i = data;
    guard = 0;
    @(posedge clk);
    while (!(wb_ack || wb_err)) begin
      @(posedge clk);
      guard++;
      if (guard > 20)
        $fatal(1, "wb_ram ack timeout");
    end
    if (wb_err)
      $fatal(1, "wb_ram unexpected err at word %0d", word);
    rdata = wb_dat_o;
    #1;
    wb_stb = 1'b0;
    wb_cyc = 1'b0;
    wb_we  = 1'b0;
  endtask

  initial begin : proc_seq
    logic [c_DATA_W-1:0] data;
    logic [c_DATA_W-1:0] readback;
    int word;
    int nwr;
    int nrd;
    int guard;
    for (int i = 0; i < c_N_WORDS; i++) begin
      shadow[i] = '0;
      wr_hit[i] = 1'b0;
      rd_hit[i] = 1'b0;
    end
    repeat (2) @(posedge clk);
    #1;
    reset = 1'b0;
    @(posedge clk);

    guard = 0;
    nwr = 0;
    nrd = 0;
    void'($urandom(seed));
    while ((nwr < c_N_WORDS) || (nrd < c_N_WORDS)) begin
      word = int'($urandom_range(c_N_WORDS - 1, 0));
      if ($urandom_range(1, 0) == 1) begin
        data = $urandom();
        shadow[word] = data;
        wb_cycle(1'b1, word, data, readback);
        if (!wr_hit[word]) begin
          wr_hit[word] = 1'b1;
          nwr++;
        end
      end else begin
        wb_cycle(1'b0, word, '0, readback);
        if (readback !== shadow[word])
          $fatal(1, "wb_ram read word %0d got %h exp %h", word, readback, shadow[word]);
        if (!rd_hit[word]) begin
          rd_hit[word] = 1'b1;
          nrd++;
        end
      end
      guard++;
      if (guard > 10000)
        $fatal(1, "wb_ram coverage timeout wr %0d rd %0d", nwr, nrd);
    end
    repeat (4) @(posedge clk);
    $display("wb_ram_tb PASS");
    $finish;
  end

  initial begin
    #1ms;
    $fatal(1, "wb_ram_tb watchdog");
  end
endmodule
