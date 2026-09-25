// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenario from bert_tb.vhdl. run.py sweeps data width and DUT delay.
// Each error count 0..width and both valid levels are hit 10 times.

`timescale 1ns/1ps

module bert_case #(
  parameter int g_DATA_WIDTH = 8,
  parameter int g_DUT_DELAY = 10
) (
  output logic done
);

  localparam int c_STATS_WIDTH = 32;
  localparam int c_COV_GOAL = 10;

  logic                            clk = 1'b1;
  logic                            reset = 1'b1;
  logic [g_DATA_WIDTH-1:0]         snk_data;
  logic [g_DATA_WIDTH-1:0]         src_data;
  logic                            snk_valid;
  logic                            src_valid;
  logic [g_DATA_WIDTH-1:0]         dut_data;
  logic [g_DATA_WIDTH-1:0]         flip_mask = '0;
  logic                            dut_valid = 1'b0;
  logic [c_STATS_WIDTH-1:0]        bits_flipped;
  logic [c_STATS_WIDTH-1:0]        total_bits;
  logic [c_STATS_WIDTH-1:0]        word_errors;
  logic [c_STATS_WIDTH-1:0]        invalid_words;
  logic [g_DATA_WIDTH-1:0]         delay_src [0:g_DUT_DELAY-1];
  logic [g_DATA_WIDTH-1:0]         delay_mask [0:g_DUT_DELAY-1];
  logic                            stim_en = 1'b0;
  int                              ber_hits [0:64];
  int                              valid_hits [0:1];

  bert #(
    .g_DATA_WIDTH(g_DATA_WIDTH),
    .g_STATS_WIDTH(c_STATS_WIDTH),
    .g_DUT_DELAY(g_DUT_DELAY)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .snk_data_i(snk_data),
    .snk_valid_i(snk_valid),
    .src_data_o(src_data),
    .src_valid_o(src_valid),
    .bit_errors_o(bits_flipped),
    .total_bits_o(total_bits),
    .word_errors_o(word_errors),
    .invalid_words_o(invalid_words)
  );

  assign snk_data  = dut_data;
  assign snk_valid = dut_valid;
  assign dut_data  = delay_src[0] ^ delay_mask[0];

  always #5 clk = ~clk;

  always @(posedge clk) begin
    for (int i = 0; i < g_DUT_DELAY - 1; i++) begin
      delay_src[i]  <= delay_src[i + 1];
      delay_mask[i] <= delay_mask[i + 1];
    end
    delay_src[g_DUT_DELAY - 1]  <= src_data;
    delay_mask[g_DUT_DELAY - 1] <= flip_mask;
  end

  always @(posedge clk) begin : proc_gen_error
    int point;
    int nfree;
    int choice;
    int seen;
    int guard;
    logic [g_DATA_WIDTH-1:0] next_mask;
    if (stim_en) begin
      point = 0;
      nfree = 0;
      for (int b = 0; b <= g_DATA_WIDTH; b++)
        if (ber_hits[b] < c_COV_GOAL)
          nfree++;
      if (nfree != 0) begin
        choice = $urandom_range(0, nfree - 1);
        seen = 0;
        for (int b = 0; b <= g_DATA_WIDTH; b++) begin
          if (ber_hits[b] < c_COV_GOAL) begin
            if (seen == choice)
              point = b;
            seen++;
          end
        end
      end
      next_mask = '0;
      guard = 0;
      for (int i = 0; i < point; i++) begin
        int nleft;
        int pick;
        int walk;
        nleft = g_DATA_WIDTH - i;
        pick = $urandom_range(0, nleft - 1);
        walk = 0;
        for (int b = 0; b < g_DATA_WIDTH; b++) begin
          if (!next_mask[b]) begin
            if (walk == pick)
              next_mask[b] = 1'b1;
            walk++;
          end
        end
        guard++;
        if (guard > g_DATA_WIDTH + 2)
          $fatal(1, "bert w=%0d: flip mask did not converge", g_DATA_WIDTH);
      end
      flip_mask <= next_mask;
      dut_valid <= 1'($urandom_range(0, 1));
    end
  end

  initial begin : proc_sequencer
    int v_point;
    int v_total_bits_flipped;
    int v_total_bits_sent;
    int v_total_invalid_words;
    int v_total_error_words;
    int steps;
    bit cov_done;
    done = 1'b0;
    for (int i = 0; i <= 64; i++)
      ber_hits[i] = 0;
    valid_hits[0] = 0;
    valid_hits[1] = 0;
    for (int i = 0; i < g_DUT_DELAY; i++) begin
      delay_src[i] = '0;
      delay_mask[i] = '0;
    end
    @(posedge clk);
    reset = 1'b0;
    stim_en = 1'b1;
    v_total_bits_flipped = 0;
    v_total_bits_sent = 0;
    v_total_invalid_words = 0;
    v_total_error_words = 0;
    // One fewer edge than the VHDL 0-to-delay loop. The DUT records the
    // popcount a cycle before this bench's first sample, and that word is
    // included in the counters.
    for (int i = 0; i < g_DUT_DELAY; i++)
      @(posedge clk);
    steps = 0;
    cov_done = 1'b0;
    while (!cov_done) begin
      @(posedge clk);
      v_total_bits_sent += g_DATA_WIDTH;
      if (dut_valid) begin
        v_point = int'($countones(delay_mask[0]));
        v_total_bits_flipped += v_point;
        if (v_point != 0)
          v_total_error_words++;
      end else begin
        v_point = 0;
        v_total_invalid_words++;
      end
      if (v_point <= g_DATA_WIDTH)
        ber_hits[v_point]++;
      valid_hits[dut_valid]++;
      cov_done = 1'b1;
      for (int b = 0; b <= g_DATA_WIDTH; b++)
        if (ber_hits[b] < c_COV_GOAL)
          cov_done = 1'b0;
      if ((valid_hits[0] < c_COV_GOAL) || (valid_hits[1] < c_COV_GOAL))
        cov_done = 1'b0;
      steps++;
      if (steps > 200000)
        $fatal(1, "bert w=%0d delay=%0d: coverage did not close", g_DATA_WIDTH, g_DUT_DELAY);
    end
    // The counters add the previous cycle's popcount. Sample them on the
    // following negedge, after that add and before the next word.
    @(posedge clk);
    @(negedge clk);
    if ((int'(bits_flipped) != v_total_bits_flipped) ||
        (int'(total_bits) != v_total_bits_sent) ||
        (int'(word_errors) != v_total_error_words) ||
        (int'(invalid_words) != v_total_invalid_words))
      $fatal(1, "bert w=%0d delay=%0d steps=%0d flips %0d/%0d bits %0d/%0d words %0d/%0d inv %0d/%0d",
             g_DATA_WIDTH, g_DUT_DELAY, steps,
             v_total_bits_flipped, bits_flipped,
             v_total_bits_sent, total_bits,
             v_total_error_words, word_errors,
             v_total_invalid_words, invalid_words);
    done = 1'b1;
  end

endmodule

module bert_tb;

  logic done [0:4][1:19];

  for (genvar wi = 0; wi < 5; wi++) begin : gen_w
    localparam int c_W = (wi == 0) ? 4 :
                         (wi == 1) ? 8 :
                         (wi == 2) ? 16 :
                         (wi == 3) ? 32 : 64;
    for (genvar d = 1; d <= 19; d++) begin : gen_d
      bert_case #(
        .g_DATA_WIDTH(c_W),
        .g_DUT_DELAY(d)
      ) u_case (
        .done(done[wi][d])
      );
    end
  end

  initial begin
    int n;
    n = 0;
    while (n != 95) begin
      #1000;
      n = 0;
      for (int wi = 0; wi < 5; wi++)
        for (int d = 1; d <= 19; d++)
          if (done[wi][d])
            n++;
    end
    $display("PASS bert_tb");
    $finish;
  end

  initial begin
    #50ms;
    $fatal(1, "timeout bert_tb");
  end

endmodule
