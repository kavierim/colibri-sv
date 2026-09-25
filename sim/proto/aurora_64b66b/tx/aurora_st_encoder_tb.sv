// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Encoder stimulus from aurora_st_encoder_tb.vhdl ("simple"): 11 packets of
// five 64-bit beats, sink ready high for three cycles and low for one.
// The VHDL bench only drove the pins. This one checks each accepted beat
// against the Aurora data word and the empty separator that follows EOP.

`timescale 1ns/1ps

module aurora_st_encoder_tb;

  localparam int c_N_LANES = 4;
  localparam int c_DATA_W  = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_ENC_W   = colibri_aurora_const::c_AURORA_ENC_WIDTH;
  localparam int c_EMPTY_W = colibri_utils::log2ceil(c_DATA_W / 8);
  logic                        clk = 1'b0;
  logic                        reset = 1'b1;
  logic                        snk_sop = 1'b0;
  logic                        snk_eop = 1'b0;
  logic                        snk_valid = 1'b0;
  logic                        snk_ready;
  logic [c_DATA_W-1:0]         snk_data = '0;
  logic [c_EMPTY_W-1:0]        snk_empty = '0;
  logic [c_ENC_W-1:0]          src_data [0:c_N_LANES-1];
  logic [c_N_LANES-1:0]        src_ready = '0;
  logic [c_N_LANES-1:0]        src_valid;

  logic [c_ENC_W-1:0] exp_q[$];
  int                 exp_matched;
  int                 accepted;

  always #2500ps clk = ~clk;

  aurora_st_encoder #(
    .g_N_LANES(c_N_LANES),
    .g_FIFO_WORDS(8)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .snk_data_i(snk_data),
    .snk_empty_i(snk_empty),
    .src_data_o(src_data),
    .src_ready_i(src_ready),
    .src_valid_o(src_valid)
  );

  function automatic logic [c_DATA_W-1:0] bswap64(input logic [c_DATA_W-1:0] vec);
    logic [c_DATA_W-1:0] result;
    for (int i = 0; i < (c_DATA_W / 8); i++)
      result[(c_DATA_W - 1) - (i * 8) -: 8] = vec[(i * 8) +: 8];
    return result;
  endfunction

  function automatic logic [c_ENC_W-1:0] enc_data(input logic [c_DATA_W-1:0] data);
    return {colibri_aurora_const::c_DATA_SH, bswap64(data)};
  endfunction

  initial begin : proc_src_ready
    src_ready = '0;
    wait (reset == 1'b0);
    @(negedge clk);
    forever begin
      src_ready = {c_N_LANES{1'b1}};
      repeat (3) @(negedge clk);
      src_ready = '0;
      @(negedge clk);
    end
  end

  initial begin : proc_check
    exp_matched = 0;
    forever begin
      @(posedge clk);
      #1ps;
      if (!reset && (&src_ready)) begin
        if (src_valid != {c_N_LANES{1'b1}})
          $fatal(1, "encoder src_valid dropped while running");
        for (int lane = 0; lane < c_N_LANES; lane++) begin
          if ((src_data[lane] == colibri_aurora_const::c_IDLE_WORD) ||
              (src_data[lane] == colibri_aurora_const::c_CB_WORD))
            continue;
          if (exp_q.size() == 0)
            $fatal(1, "unexpected lane %0d word %h", lane, src_data[lane]);
          if (src_data[lane] != exp_q[0])
            $fatal(1, "lane %0d got %h exp %h", lane, src_data[lane], exp_q[0]);
          exp_q.pop_front();
          exp_matched++;
        end
      end
    end
  end

  task automatic tick;
    @(posedge clk);
    #1ps;
  endtask

  task automatic wait_sink_ready;
    int guard;
    guard = 0;
    while (snk_ready != 1'b1) begin
      tick();
      guard++;
      if (guard > 5000)
        $fatal(1, "encoder snk_ready timeout");
    end
  endtask

  task automatic send_beat(
    input logic [c_DATA_W-1:0] data,
    input logic                sop,
    input logic                eop
  );
    exp_q.push_back(enc_data(data));
    if (eop)
      exp_q.push_back(colibri_aurora_const::c_EMPTY_SEP_WORD);
    wait_sink_ready();
    snk_data  = data;
    snk_empty = '0;
    snk_sop   = sop;
    snk_eop   = eop;
    snk_valid = 1'b1;
    tick();
    accepted++;
    snk_valid = 1'b0;
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
  endtask

  initial begin : proc_main
    logic [55:0] vec;
    logic [c_DATA_W-1:0] beat;
    accepted = 0;
    snk_valid = 1'b0;
    reset = 1'b1;
    repeat (4) @(posedge clk);
    reset = 1'b0;

    for (int i = 0; i < 11; i++) begin
      for (int j = 0; j < 7; j++)
        vec[(55 - (j * 8)) -: 8] = 8'(j + i * 16);
      beat = {8'haa, vec};
      send_beat(beat, 1'b1, 1'b0);
      beat = {8'hbb, vec};
      send_beat(beat, 1'b0, 1'b0);
      beat = {8'hcc, vec};
      send_beat(beat, 1'b0, 1'b0);
      beat = {8'hdd, vec};
      send_beat(beat, 1'b0, 1'b0);
      beat = {8'hee, vec};
      send_beat(beat, 1'b0, 1'b1);
    end

    begin
      int guard;
      guard = 0;
      while (exp_q.size() != 0) begin
        tick();
        guard++;
        if (guard > 20000)
          $fatal(1, "encoder scoreboard timeout, %0d words left", exp_q.size());
      end
    end

    if (accepted != 55)
      $fatal(1, "accepted %0d beats, expected 55", accepted);
    if (exp_matched != 66)
      $fatal(1, "matched %0d encoded words, expected 66", exp_matched);

    $display("PASS aurora_st_encoder_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #100us;
    $fatal(1, "aurora_st_encoder_tb timeout");
  end

endmodule
