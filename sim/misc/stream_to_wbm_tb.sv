// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-check for stream_to_wbm. Initializes 16 words, then random reads and
// writes until every address has been both written and read.

`timescale 1ns/1ps

module stream_to_wbm_tb;

  // verilator lint_off REALCVT
  localparam time c_CLK_PERIOD = 5ns;
  // verilator lint_on REALCVT
  localparam int c_HDR_WIDTH   = 8;
  localparam int c_WB_WIDTH    = 32;
  localparam int c_STR_WIDTH   = c_HDR_WIDTH + c_WB_WIDTH;
  localparam logic [7:0] c_CMD_ADDR  = 8'h01;
  localparam logic [7:0] c_CMD_RDATA = 8'h02;
  localparam logic [7:0] c_CMD_WDATA = 8'h03;
  localparam logic [7:0] c_ACK_ADDR  = 8'h11;
  localparam logic [7:0] c_ACK_RDATA = 8'h12;
  localparam logic [7:0] c_ACK_WDATA = 8'h13;
  localparam int c_MAX_TRIALS = 256;

  logic clk   = 1'b1;
  logic reset = 1'b1;
  logic [c_STR_WIDTH-1:0] snk_data;
  logic snk_valid = 1'b0;
  logic snk_ready;
  logic [c_STR_WIDTH-1:0] src_data;
  logic src_valid;
  logic [c_WB_WIDTH-1:0] wb_adr;
  logic [c_WB_WIDTH-1:0] wb_wdat;
  logic [c_WB_WIDTH-1:0] wb_rdat;
  logic wb_we;
  logic [3:0] wb_sel;
  logic wb_stb;
  logic wb_cyc;
  logic wb_ack;
  logic wb_err = 1'b0;

  logic [c_WB_WIDTH-1:0] mem[0:15];
  logic [c_WB_WIDTH-1:0] model[0:15];
  bit wr_hit[0:15];
  bit rd_hit[0:15];

  stream_to_wbm dut (
    .clk_i      (clk),
    .reset_i    (reset),
    .snk_data_i (snk_data),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .src_data_o (src_data),
    .src_valid_o(src_valid),
    .wb_adr_o   (wb_adr),
    .wb_dat_i   (wb_rdat),
    .wb_dat_o   (wb_wdat),
    .wb_we_o    (wb_we),
    .wb_sel_o   (wb_sel),
    .wb_stb_o   (wb_stb),
    .wb_cyc_o   (wb_cyc),
    .wb_ack_i   (wb_ack),
    .wb_err_i   (wb_err)
  );

  assign wb_ack  = wb_stb & wb_cyc;
  assign wb_rdat = mem[wb_adr[5:2]];

  always #(c_CLK_PERIOD / 2) clk = ~clk;

  always @(posedge clk) begin : proc_mem
    if (wb_stb && wb_cyc && wb_we)
      mem[wb_adr[5:2]] <= wb_wdat;
  end

  function automatic bit covered();
    for (int i = 0; i < 16; i++)
      if (!wr_hit[i] || !rd_hit[i])
        return 1'b0;
    return 1'b1;
  endfunction

  task automatic push(input logic [c_STR_WIDTH-1:0] word);
    @(negedge clk);
    snk_data  = word;
    snk_valid = 1'b1;
    do @(posedge clk); while (!snk_ready);
    @(negedge clk);
    snk_valid = 1'b0;
  endtask

  task automatic pop(output logic [c_STR_WIDTH-1:0] word);
    int guard;
    guard = 0;
    // The reply is valid on the negedge that ends the input beat.
    if (!src_valid)
      @(negedge clk);
    while (!src_valid) begin
      @(negedge clk);
      guard++;
      if (guard > 40)
        $fatal(1, "stream response timeout");
    end
    word = src_data;
  endtask

  task automatic memop(
    input bit do_write,
    input logic [31:0] addr,
    input logic [31:0] data,
    output logic [31:0] got
  );
    logic [c_STR_WIDTH-1:0] resp;
    push({c_CMD_ADDR, addr});
    pop(resp);
    if (resp[c_STR_WIDTH-1 -: c_HDR_WIDTH] !== c_ACK_ADDR)
      $fatal(1, "address ack header %h", resp[c_STR_WIDTH-1 -: c_HDR_WIDTH]);
    if (resp[31:0] !== addr)
      $fatal(1, "address echo exp %h got %h", addr, resp[31:0]);
    if (do_write) begin
      push({c_CMD_WDATA, data});
      pop(resp);
      if (resp[c_STR_WIDTH-1 -: c_HDR_WIDTH] !== c_ACK_WDATA)
        $fatal(1, "write ack header %h", resp[c_STR_WIDTH-1 -: c_HDR_WIDTH]);
      got = data;
    end else begin
      push({c_CMD_RDATA, data});
      pop(resp);
      if (resp[c_STR_WIDTH-1 -: c_HDR_WIDTH] !== c_ACK_RDATA)
        $fatal(1, "read ack header %h", resp[c_STR_WIDTH-1 -: c_HDR_WIDTH]);
      got = resp[31:0];
    end
  endtask

  initial begin : proc_test
    logic [31:0] addr;
    logic [31:0] data;
    logic [31:0] got;
    int slot;
    void'($urandom(32'hC011_5701));
    for (int i = 0; i < 16; i++) begin
      mem[i]    = '0;
      model[i]  = '0;
      wr_hit[i] = 1'b0;
      rd_hit[i] = 1'b0;
    end
    snk_data  = '0;
    snk_valid = 1'b0;

    repeat (4) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    @(posedge clk);

    for (int k = 0; k < 16; k++) begin
      addr = 32'(k * 4);
      data = $urandom();
      memop(1'b1, addr, data, got);
      model[k] = data;
      #(c_CLK_PERIOD);
    end

    #1us;

    for (int n = 0; n < c_MAX_TRIALS; n++) begin
      if (covered())
        break;
      slot = $urandom_range(0, 15);
      addr = 32'(slot * 4);
      if ($urandom_range(0, 1) == 1) begin
        data = $urandom();
        model[slot] = data;
        memop(1'b1, addr, data, got);
        wr_hit[slot] = 1'b1;
      end else begin
        memop(1'b0, addr, 32'h0, got);
        if (got !== model[slot])
          $fatal(1, "read mismatch addr %h got %h exp %h", addr, got, model[slot]);
        rd_hit[slot] = 1'b1;
      end
      #(5 * c_CLK_PERIOD);
    end

    if (!covered())
      $fatal(1, "read/write coverage was not met");
    $display("PASS stream_to_wbm_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #5ms;
    $fatal(1, "stream_to_wbm_tb watchdog");
  end

endmodule
