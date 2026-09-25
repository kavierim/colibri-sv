// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Throughput loopback from aurora_throughput_tb.vhdl. Lane widths 8, 16, 32
// and lane counts 1..4 match run.py. Each lane is bit-shifted by
// 31*(lane+1) mod width. An all-zero word brings the decoder out of its
// first-packet drop, then random packets must match exactly.
// VHDL draws 10 packets of 1024..8192 bytes. This bench sends three packets
// of 16, 15, and 9 bytes (seed 42), which still checks a full word, a SEP7
// tail, and a one-byte SEP tail.

`timescale 1ns/1ps

module aurora_throughput_harness #(
  parameter int g_N_LANES    = 1,
  parameter int g_LANE_WIDTH = 32
) (
  output logic done_o
);

  localparam int c_NUM_PACKETS = 3;
  localparam int c_DATA_W      = colibri_aurora_const::c_AURORA_DATA_WIDTH;
  localparam int c_EMPTY_W     = colibri_utils::log2ceil(c_DATA_W / 8);
  localparam int c_OFF_W       = colibri_utils::downto_width(colibri_utils::log2ceil(g_LANE_WIDTH));
  localparam int c_DEC_HALF_PS = (25000 / g_N_LANES) / 2;
  localparam int c_LEN0        = 16;
  localparam int c_LEN1        = 15;
  localparam int c_LEN2        = 9;

  logic                  enc_clk = 1'b0;
  logic                  tx_clk = 1'b0;
  logic                  dec_clk = 1'b0;
  logic                  enc_reset = 1'b1;
  logic                  tx_reset = 1'b1;
  logic                  dec_reset = 1'b1;
  logic                  snk_sop = 1'b0;
  logic                  snk_eop = 1'b0;
  logic                  snk_valid = 1'b0;
  logic                  snk_ready;
  logic [c_DATA_W-1:0]   snk_data = '0;
  logic [c_EMPTY_W-1:0]  snk_empty = '0;
  logic [g_LANE_WIDTH-1:0] tx_data [0:g_N_LANES-1];
  logic [g_LANE_WIDTH-1:0] shift_data [0:g_N_LANES-1];
  logic [g_N_LANES-1:0]  tx_valid;
  logic                  src_sop;
  logic                  src_eop;
  logic                  src_valid;
  logic                  src_error;
  logic [c_DATA_W-1:0]   src_data;
  logic [c_EMPTY_W-1:0]  src_empty;
  logic                  link_up;

  logic [7:0] pkt_mem [0:c_NUM_PACKETS-1][0:15];
  int         pkt_len [0:c_NUM_PACKETS-1];
  int         rnd_state;
  int         exp_len_q[$];
  logic [7:0] exp_byte_q[$];
  int         got_packets;
  int         exp_packets;
  // Written only from proc_main. Verilator 5.020 duplicates a flag
  // that is assigned from more than one initial process.
  int         checking;

  always #5000ps enc_clk = ~enc_clk;
  always #12500ps tx_clk = ~tx_clk;
  always #(c_DEC_HALF_PS * 1ps) dec_clk = ~dec_clk;

  aurora_tx #(
    .g_N_LANES(g_N_LANES),
    .g_LANE_WIDTH(g_LANE_WIDTH)
  ) tx_dut (
    .snk_clk_i(enc_clk),
    .snk_reset_i(enc_reset),
    .src_clk_i(tx_clk),
    .snk_sop_i(snk_sop),
    .snk_eop_i(snk_eop),
    .snk_valid_i(snk_valid),
    .snk_ready_o(snk_ready),
    .snk_data_i(snk_data),
    .snk_empty_i(snk_empty),
    .src_data_o(tx_data),
    .src_valid_o(tx_valid),
    .src_ready_i({g_N_LANES{1'b1}})
  );

  for (genvar lane = 0; lane < g_N_LANES; lane++) begin : gen_lane_shifts
    localparam int c_SHIFT = (31 * (lane + 1)) % g_LANE_WIDTH;
    bit_shifter #(
      .g_DATA_WIDTH(g_LANE_WIDTH),
      .g_MSB_RIGHT(1'b0)
    ) bit_shifter_inst (
      .clk_i(tx_clk),
      .reset_i(tx_reset),
      .offset_i(c_OFF_W'(c_SHIFT)),
      .data_i(tx_data[lane]),
      .data_o(shift_data[lane])
    );
  end

  aurora_rx #(
    .g_N_LANES(g_N_LANES),
    .g_LANE_WIDTH(g_LANE_WIDTH),
    .g_USE_OPTIMIZED_GBX(1'b1)
  ) rx_dut (
    .snk_clk_i(tx_clk),
    .src_clk_i(dec_clk),
    .src_reset_i(dec_reset),
    .snk_valid_i({g_N_LANES{1'b1}}),
    .snk_data_i(shift_data),
    .src_sop_o(src_sop),
    .src_eop_o(src_eop),
    .src_valid_o(src_valid),
    .src_error_o(src_error),
    .src_data_o(src_data),
    .src_empty_o(src_empty),
    .src_link_up_o(link_up)
  );

  function automatic int next_rnd;
    rnd_state = int'((32'(rnd_state) * 32'h41C64E6D + 32'h3039) & 32'h7fff_ffff);
    return rnd_state;
  endfunction

  task automatic enc_tick;
    @(posedge enc_clk);
    #1ps;
  endtask

  task automatic send_bytes(input int pkt_i, input bit queue_it);
    int nwords;
    int nbytes;
    int remain;
    int empty;
    int guard;
    int length;
    logic [c_DATA_W-1:0] word;
    length = pkt_len[pkt_i];
    nwords = (length + 7) / 8;
    if (queue_it) begin
      exp_len_q.push_back(length);
      for (int b = 0; b < length; b++)
        exp_byte_q.push_back(pkt_mem[pkt_i][b]);
      exp_packets++;
    end
    for (int word_i = 0; word_i < nwords; word_i++) begin
      remain = length - word_i * 8;
      nbytes = (remain > 8) ? 8 : remain;
      empty  = 8 - nbytes;
      word   = '0;
      for (int b = 0; b < nbytes; b++)
        word[(c_DATA_W - 1) - (b * 8) -: 8] = pkt_mem[pkt_i][word_i * 8 + b];
      guard = 0;
      while (snk_ready != 1'b1) begin
        enc_tick();
        guard++;
        if (guard > 200000)
          $fatal(1, "throughput ready timeout lanes=%0d width=%0d", g_N_LANES, g_LANE_WIDTH);
      end
      snk_data  = word;
      snk_empty = c_EMPTY_W'(empty);
      snk_sop   = (word_i == 0);
      snk_eop   = (word_i == nwords - 1);
      snk_valid = 1'b1;
      enc_tick();
    end
    snk_valid = 1'b0;
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
    enc_tick();
  endtask

  task automatic send_zero_word;
    int guard;
    guard = 0;
    while (snk_ready != 1'b1) begin
      enc_tick();
      guard++;
      if (guard > 200000)
        $fatal(1, "throughput init ready timeout lanes=%0d width=%0d", g_N_LANES, g_LANE_WIDTH);
    end
    snk_data  = '0;
    snk_empty = '0;
    snk_sop   = 1'b1;
    snk_eop   = 1'b1;
    snk_valid = 1'b1;
    enc_tick();
    snk_valid = 1'b0;
    snk_sop   = 1'b0;
    snk_eop   = 1'b0;
    enc_tick();
  endtask

  initial begin
    enc_reset = 1'b1;
    tx_reset  = 1'b1;
    dec_reset = 1'b1;
    #1us;
    enc_reset = 1'b0;
    #100ns;
    tx_reset = 1'b0;
    #100ns;
    dec_reset = 1'b0;
  end

  initial begin : proc_monitor
    logic [7:0] got[$];
    int nbytes;
    int pkt_i;
    got_packets = 0;
    pkt_i       = 0;
    forever begin
      @(posedge dec_clk);
      #1ps;
      if (dec_reset) begin
        got = {};
      end else if ((checking != 0) && src_valid) begin
        if (src_error)
          $fatal(1, "throughput error lanes=%0d width=%0d packet=%0d",
                 g_N_LANES, g_LANE_WIDTH, pkt_i);
        if (src_sop && (got.size() != 0))
          $fatal(1, "throughput SOP while open lanes=%0d width=%0d packet=%0d",
                 g_N_LANES, g_LANE_WIDTH, pkt_i);
        if (!src_sop && (got.size() == 0))
          $fatal(1, "throughput data without SOP lanes=%0d width=%0d",
                 g_N_LANES, g_LANE_WIDTH);
        if (!src_eop && (src_empty != '0))
          $fatal(1, "throughput empty before EOP lanes=%0d width=%0d",
                 g_N_LANES, g_LANE_WIDTH);
        nbytes = src_eop ? (8 - int'(src_empty)) : 8;
        if ((nbytes < 1) || (nbytes > 8))
          $fatal(1, "throughput empty %0d lanes=%0d width=%0d",
                 src_empty, g_N_LANES, g_LANE_WIDTH);
        for (int b = 0; b < nbytes; b++)
          got.push_back(src_data[(c_DATA_W - 1) - (b * 8) -: 8]);
        if (src_eop) begin
          if (exp_len_q.size() == 0)
            $fatal(1, "throughput unexpected packet lanes=%0d width=%0d len=%0d",
                   g_N_LANES, g_LANE_WIDTH, got.size());
          if (got.size() != exp_len_q[0])
            $fatal(1, "throughput length lanes=%0d width=%0d pkt=%0d got=%0d exp=%0d",
                   g_N_LANES, g_LANE_WIDTH, pkt_i, got.size(), exp_len_q[0]);
          for (int b = 0; b < got.size(); b++) begin
            if (got[b] != exp_byte_q[0])
              $fatal(1, "throughput data lanes=%0d width=%0d pkt=%0d byte=%0d got=%02x exp=%02x",
                     g_N_LANES, g_LANE_WIDTH, pkt_i, b, got[b], exp_byte_q[0]);
            exp_byte_q.pop_front();
          end
          exp_len_q.pop_front();
          got = {};
          got_packets++;
          pkt_i++;
        end
      end
    end
  end

  initial begin : proc_main
    int guard;
    done_o      = 1'b0;
    exp_packets = 0;
    checking    = 0;
    rnd_state   = 42;
    pkt_len[0]  = c_LEN0;
    pkt_len[1]  = c_LEN1;
    pkt_len[2]  = c_LEN2;
    for (int p = 0; p < c_NUM_PACKETS; p++)
      for (int b = 0; b < pkt_len[p]; b++)
        pkt_mem[p][b] = 8'(next_rnd());

    wait (dec_reset == 1'b0);
    guard = 0;
    while (link_up != 1'b1) begin
      @(posedge dec_clk);
      #1ps;
      guard++;
      if (guard > 80000)
        $fatal(1, "throughput link_up timeout lanes=%0d width=%0d", g_N_LANES, g_LANE_WIDTH);
    end

    send_zero_word();
    checking = 1;
    for (int p = 0; p < c_NUM_PACKETS; p++)
      send_bytes(p, 1'b1);

    guard = 0;
    while (got_packets != exp_packets) begin
      @(posedge dec_clk);
      #1ps;
      guard++;
      if (guard > 400000)
        $fatal(1, "throughput got %0d of %0d lanes=%0d width=%0d",
               got_packets, exp_packets, g_N_LANES, g_LANE_WIDTH);
    end
    done_o = 1'b1;
  end

endmodule

module aurora_throughput_tb;

  logic done_flag [0:2][0:3];

  for (genvar wi = 0; wi < 3; wi++) begin : gen_width
    for (genvar li = 0; li < 4; li++) begin : gen_lanes
      localparam int c_W = (wi == 0) ? 8 : ((wi == 1) ? 16 : 32);
      localparam int c_L = li + 1;
      aurora_throughput_harness #(
        .g_N_LANES(c_L),
        .g_LANE_WIDTH(c_W)
      ) harness (
        .done_o(done_flag[wi][li])
      );
    end
  end

  initial begin : proc_join
    for (int wi = 0; wi < 3; wi++)
      for (int li = 0; li < 4; li++)
        wait (done_flag[wi][li] == 1'b1);
    $display("PASS aurora_throughput_tb");
    $finish;
  end

  initial begin : proc_watchdog
    #5ms;
    $fatal(1, "aurora_throughput_tb timeout");
  end

endmodule
