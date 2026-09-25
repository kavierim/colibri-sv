// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// Integer array round-trip through unsigned and std_logic_vector arrays.
// sim/common/type_conv_tb.vhdl, element width 16, values 1..12.
module type_conv_tb;

  localparam int c_ELEM = 16;
  localparam int c_LEN  = 12;
  localparam time c_CLK = 10ns;

  int                init_a [0:c_LEN-1];
  int                int_a [0:c_LEN-1];
  logic [c_ELEM-1:0] uns_a [0:c_LEN-1];
  logic [c_ELEM-1:0] slv_a [0:c_LEN-1];
  logic [c_LEN*c_ELEM-1:0] slv;
  logic              clk;

  initial begin
    clk = 1'b1;
    forever begin
      #(c_CLK / 2) clk = 1'b0;
      #(c_CLK / 2) clk = 1'b1;
    end
  end

  initial begin
    init_a = '{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
    @(posedge clk);
    uns_a = colibri_types::uns_arr#(c_LEN, c_ELEM, c_ELEM)::from_int(init_a);
    @(posedge clk);
    slv = colibri_types::uns_arr#(c_LEN, c_ELEM, c_ELEM)::to_slv(uns_a);
    @(posedge clk);
    slv_a = colibri_types::slv_arr#(c_LEN, c_ELEM)::from_slv(slv);
    @(posedge clk);
    slv = colibri_types::slv_arr#(c_LEN, c_ELEM)::to_slv(slv_a);
    @(posedge clk);
    uns_a = colibri_types::uns_arr#(c_LEN, c_ELEM, c_ELEM)::from_slv(slv);
    @(posedge clk);
    int_a = colibri_types::uns_arr#(c_LEN, c_ELEM)::to_int(uns_a);
    @(posedge clk);
    for (int i = 0; i < c_LEN; i++) begin
      if (int_a[i] !== init_a[i])
        $fatal(1, "value[%0d] changed: got %0d expected %0d", i, int_a[i], init_a[i]);
    end
    repeat (3) @(posedge clk);
    $display("PASS type_conv_tb");
    $finish;
  end

endmodule
