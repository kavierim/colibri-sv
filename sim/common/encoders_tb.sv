// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Priority encoder checks from sim/common/encoders_tb.vhdl.
module encoders_tb;

  function automatic int floor_log2(input int value);
    int idx;
    int v;
    idx = 0;
    v   = value;
    if (v <= 0)
      return 0;
    while (v > 1) begin
      v   = v >> 1;
      idx = idx + 1;
    end
    return idx;
  endfunction

  logic [7:0] test_vec;
  logic [2:0] encoded;
  int         expected;

  initial begin
    for (int i = 0; i < 256; i++) begin
      test_vec = 8'(i);
      expected = floor_log2(i);
      encoded  = colibri_encoders::pri#(8)::priority_encode(test_vec);
      #10;
      if (expected !== int'(encoded))
        $fatal(1, "priority encoding %0d: got %0d expected %0d", i, encoded, expected);
    end
    $display("PASS encoders_tb");
    $finish;
  end

endmodule
