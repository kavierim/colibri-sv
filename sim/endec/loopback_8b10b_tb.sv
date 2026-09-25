// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// 8b/10b encode/decode loopback.
// Coverage: one OSVVM bin for data 0..255 and one bin per legal K word.
//   A point is drawn from an uncovered bin, encoded, decoded, and compared.
// Illegal: one bin per illegal K range. The encoder must not emit a non-zero
//   symbol for those words.

`timescale 1ns/1ps

module loopback_8b10b_tb;
  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic [8:0] snk_data  = '0;
  logic       snk_valid = 1'b0;
  logic [9:0] enc_data;
  logic       enc_valid;
  logic [7:0] src_data;
  logic       src_control;
  logic       src_valid;

  encode_8b10b encoder_8b10b_inst (
    .clk_i         (clk),
    .snk_data_i    (snk_data[7:0]),
    .snk_valid_i   (snk_valid),
    .snk_control_i (snk_data[8]),
    .src_data_o    (enc_data),
    .src_valid_o   (enc_valid)
  );

  decode_8b10b decoder_8b10b_inst (
    .clk_i         (clk),
    .snk_data_i    (enc_data),
    .snk_valid_i   (enc_valid),
    .src_data_o    (src_data),
    .src_control_o (src_control),
    .src_valid_o   (src_valid)
  );

  localparam logic [8:0] K_SYM [0:11] = '{
    9'd284, 9'd316, 9'd348, 9'd380, 9'd412, 9'd444,
    9'd476, 9'd503, 9'd507, 9'd508, 9'd509, 9'd510
  };
  localparam int IL_LO [0:9] = '{256, 285, 317, 349, 381, 413, 445, 477, 504, 511};
  localparam int IL_HI [0:9] = '{283, 315, 347, 379, 411, 443, 475, 502, 506, 511};

  bit hit_data;
  bit hit_k [0:11];
  bit hit_il [0:9];

  initial begin
    #1ms;
    $fatal(1, "loopback_8b10b_tb timeout");
  end

  task automatic step();
    @(posedge clk);
    #1;
  endtask

  task automatic idle(input int n);
    snk_valid = 1'b0;
    repeat (n) step();
  endtask

  function automatic logic covered_legal();
    int i;
    if (!hit_data)
      return 1'b0;
    for (i = 0; i < 12; i++) begin
      if (!hit_k[i])
        return 1'b0;
    end
    return 1'b1;
  endfunction

  function automatic logic covered_illegal();
    int i;
    for (i = 0; i < 10; i++) begin
      if (!hit_il[i])
        return 1'b0;
    end
    return 1'b1;
  endfunction

  function automatic logic [8:0] draw_legal();
    int open_i [0:12];
    int nopen;
    int pick;
    int idx;
    int i;
    nopen = 0;
    if (!hit_data) begin
      open_i[nopen] = 0;
      nopen++;
    end
    for (i = 0; i < 12; i++) begin
      if (!hit_k[i]) begin
        open_i[nopen] = i + 1;
        nopen++;
      end
    end
    if (nopen == 0)
      $fatal(1, "draw_legal called with full coverage");
    pick = $urandom_range(0, nopen - 1);
    idx  = open_i[pick];
    if (idx == 0)
      return 9'($urandom_range(0, 255));
    return K_SYM[idx - 1];
  endfunction

  function automatic int draw_illegal_bin();
    int open_i [0:9];
    int nopen;
    int i;
    nopen = 0;
    for (i = 0; i < 10; i++) begin
      if (!hit_il[i]) begin
        open_i[nopen] = i;
        nopen++;
      end
    end
    if (nopen == 0)
      $fatal(1, "draw_illegal_bin called with full coverage");
    return open_i[$urandom_range(0, nopen - 1)];
  endfunction

  task automatic note_legal(input logic [8:0] sym);
    int i;
    if (sym <= 9'd255)
      hit_data = 1'b1;
    for (i = 0; i < 12; i++) begin
      if (sym == K_SYM[i])
        hit_k[i] = 1'b1;
    end
  endtask

  task automatic xfer(input logic [8:0] sym, output logic [8:0] got);
    int guard;
    if ($urandom_range(0, 1) == 0)
      idle($urandom_range(1, 8));
    snk_data  = sym;
    snk_valid = 1'b1;
    step();
    snk_valid = 1'b0;
    guard = 0;
    do begin
      step();
      guard++;
    end while (!src_valid && guard < 8);
    if (!src_valid)
      $fatal(1, "loopback timeout for symbol %0d", sym);
    got = {src_control, src_data};
    step();
  endtask

  task automatic illegal_beat(input logic [8:0] sym);
    snk_data  = sym;
    snk_valid = 1'b1;
    step();
    snk_valid = 1'b0;
    step();
    if (enc_valid && (enc_data != '0))
      $fatal(1, "Invalid data passed through %0h => %0h", sym, enc_data);
    idle(4);
  endtask

  initial begin : proc_seq
    logic [8:0] sent;
    logic [8:0] recv;
    int         bin;
    int         point;
    int         guard;
    repeat (2) step();

    guard = 0;
    while (!covered_legal() && guard < 32) begin
      sent = draw_legal();
      xfer(sent, recv);
      if (recv != sent)
        $fatal(1, "Data mismatch %0h =/= %0h", sent, recv);
      note_legal(recv);
      guard++;
    end
    if (!covered_legal())
      $fatal(1, "legal 8b10b coverage incomplete");

    idle(4);

    guard = 0;
    while (!covered_illegal() && guard < 32) begin
      bin   = draw_illegal_bin();
      point = $urandom_range(IL_LO[bin], IL_HI[bin]);
      illegal_beat(point[8:0]);
      hit_il[bin] = 1'b1;
      guard++;
    end
    if (!covered_illegal())
      $fatal(1, "illegal K coverage incomplete");

    $display("PASS: loopback_8b10b_tb");
    $finish;
  end

endmodule
