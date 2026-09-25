// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// 8b/10b decoder bench. Every 10b code is applied, with bounded random gaps.
// Each beat is checked against the decode ROM. The OSVVM bins are one bin for
// data 0..255 and one bin for each legal K word.

`timescale 1ns/1ps

module decode_8b10b_tb;
  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic [9:0] snk_data  = '0;
  logic       snk_valid = 1'b0;
  logic [7:0] src_data;
  logic       src_control;
  logic       src_valid;

  decode_8b10b dut (
    .clk_i         (clk),
    .snk_data_i    (snk_data),
    .snk_valid_i   (snk_valid),
    .src_data_o    (src_data),
    .src_control_o (src_control),
    .src_valid_o   (src_valid)
  );

  localparam logic [8:0] K_SYM [0:11] = '{
    9'd284, 9'd316, 9'd348, 9'd380, 9'd412, 9'd444,
    9'd476, 9'd503, 9'd507, 9'd508, 9'd509, 9'd510
  };

  bit  hit_data;
  bit  hit_k [0:11];
  bit  timed_out;

  typedef struct packed {
    logic       valid;
    logic [7:0] data;
    logic       ctrl;
    logic [9:0] code;
  } exp_t;

  exp_t pipe;
  bit   pipe_full;

  initial begin
    #1ms;
    timed_out = 1'b1;
    $fatal(1, "decode_8b10b_tb timeout");
  end

  task automatic step();
    @(posedge clk);
    #1;
  endtask

  function automatic void note(input logic [8:0] sym);
    int i;
    if (sym <= 9'd255)
      hit_data = 1'b1;
    for (i = 0; i < 12; i++) begin
      if (sym == K_SYM[i])
        hit_k[i] = 1'b1;
    end
  endfunction

  task automatic drive(input logic valid, input logic [9:0] code);
    logic [9:0] romw;
    exp_t       cur;
    romw = colibri_common_8b10b::c_DECODE_ROM_8B10B[code];
    cur.valid = valid && ~(&romw);
    cur.data  = romw[9:2];
    cur.ctrl  = romw[0];
    cur.code  = code;
    snk_valid = valid;
    snk_data  = code;
    step();
    if (pipe_full) begin
      if (src_valid != pipe.valid)
        $fatal(1, "decode valid mismatch code=%0d exp_valid=%0b got=%0b",
               pipe.code, pipe.valid, src_valid);
      if (pipe.valid) begin
        if (src_data != pipe.data || src_control != pipe.ctrl)
          $fatal(1, "decode data mismatch code=%0d exp=%0h got=%0h k=%0b",
                 pipe.code, {pipe.ctrl, pipe.data}, {src_control, src_data}, src_control);
        note({src_control, src_data});
      end
    end
    pipe      = cur;
    pipe_full = 1'b1;
  endtask

  initial begin : proc_seq
    int i;
    int nstall;
    int missing;
    repeat (2) step();

    for (i = 0; i < 1024; i++) begin
      if ($urandom_range(0, 1) == 0) begin
        nstall = $urandom_range(1, 8);
        repeat (nstall)
          drive(1'b0, snk_data);
      end
      drive(1'b1, i[9:0]);
    end
    drive(1'b0, '0);
    drive(1'b0, '0);

    if (!hit_data)
      $fatal(1, "DATA bin 0..255 was not covered");
    missing = 0;
    for (i = 0; i < 12; i++) begin
      if (!hit_k[i]) begin
        missing++;
        $fatal(1, "K bin %0d was not covered", K_SYM[i]);
      end
    end
    if (missing != 0)
      $fatal(1, "decode coverage incomplete");

    $display("PASS: decode_8b10b_tb");
    $finish;
  end

endmodule
