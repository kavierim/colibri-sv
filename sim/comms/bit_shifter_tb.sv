// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Scenarios from bit_shifter_tb.vhdl, including the run.py width and orientation sweep.

`timescale 1ns/1ps

module bit_shifter_case #(
  parameter int g_DATA_WIDTH = 8,
  parameter bit g_MSB_RIGHT = 1'b1
) (
  output logic done
);

  localparam int c_OFF_W = colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH));

  logic                      clk = 1'b0;
  logic                      reset = 1'b1;
  logic [c_OFF_W-1:0]        offset = '0;
  logic [g_DATA_WIDTH-1:0]   data_i = '0;
  logic [g_DATA_WIDTH-1:0]   data_o;

  bit_shifter #(
    .g_DATA_WIDTH(g_DATA_WIDTH),
    .g_MSB_RIGHT(g_MSB_RIGHT)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .offset_i(offset),
    .data_i(data_i),
    .data_o(data_o)
  );

  always #5 clk = ~clk;

  initial begin : proc_stimulation
    int off;
    logic [g_DATA_WIDTH-1:0] exp;
    int half;
    done = 1'b0;
    half = (g_DATA_WIDTH - 1) / 2;
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    @(posedge clk);

    @(negedge clk);
    data_i = g_DATA_WIDTH'(10);
    offset = '0;
    @(posedge clk);
    #1;
    if (data_o != g_DATA_WIDTH'(10))
      $fatal(1, "bit_shifter w=%0d msb_right=%0d: data did not propagate in 1 clock",
             g_DATA_WIDTH, g_MSB_RIGHT);

    repeat (5) @(posedge clk);
    #1;
    if (data_o != g_DATA_WIDTH'(10))
      $fatal(1, "bit_shifter w=%0d msb_right=%0d: output did not persist",
             g_DATA_WIDTH, g_MSB_RIGHT);

    @(negedge clk);
    data_i = '0;
    data_i[g_DATA_WIDTH / 2] = 1'b1;
    for (off = 1; off <= half; off++) begin
      offset = c_OFF_W'(off);
      @(posedge clk);
      #1;
      exp = g_MSB_RIGHT ? (data_i << off) : (data_i >> off);
      if (data_o != exp)
        $fatal(1, "bit_shifter w=%0d msb_right=%0d off=%0d: shift mismatch got %h exp %h",
               g_DATA_WIDTH, g_MSB_RIGHT, off, data_o, exp);
    end

    repeat (5) @(posedge clk);
    #1;
    exp = g_MSB_RIGHT ? (data_i << half) : (data_i >> half);
    if (data_o != exp)
      $fatal(1, "bit_shifter w=%0d msb_right=%0d: output did not persist after shift",
             g_DATA_WIDTH, g_MSB_RIGHT);

    for (off = half + 2; off <= (g_DATA_WIDTH - 1); off++) begin
      @(negedge clk);
      offset = c_OFF_W'(off);
      @(posedge clk);
      #1;
      exp = g_MSB_RIGHT ? (data_i >> (g_DATA_WIDTH - off))
                        : (data_i << (g_DATA_WIDTH - off));
      if (data_o != exp)
        $fatal(1, "bit_shifter w=%0d msb_right=%0d off=%0d: word-edge mismatch got %h exp %h",
               g_DATA_WIDTH, g_MSB_RIGHT, off, data_o, exp);
    end

    repeat (5) @(posedge clk);
    done = 1'b1;
  end

endmodule

module bit_shifter_tb;

  logic done [0:6][0:1];

  for (genvar wi = 0; wi < 7; wi++) begin : gen_w
    localparam int c_W = (wi == 0) ? 8 :
                         (wi == 1) ? 11 :
                         (wi == 2) ? 32 :
                         (wi == 3) ? 43 :
                         (wi == 4) ? 64 :
                         (wi == 5) ? 97 : 128;
    for (genvar msb = 0; msb < 2; msb++) begin : gen_m
      bit_shifter_case #(
        .g_DATA_WIDTH(c_W),
        .g_MSB_RIGHT(msb[0])
      ) u_case (
        .done(done[wi][msb])
      );
    end
  end

  initial begin
    int n;
    n = 0;
    while (n != 14) begin
      #100;
      n = 0;
      for (int wi = 0; wi < 7; wi++)
        for (int msb = 0; msb < 2; msb++)
          if (done[wi][msb])
            n++;
    end
    $display("PASS bit_shifter_tb");
    $finish;
  end

  initial begin
    #2ms;
    $fatal(1, "timeout bit_shifter_tb");
  end

endmodule
