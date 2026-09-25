// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Self-checking translation of sim/memory/ram_tb.vhdl.
// The VUnit run sweeps g_REGISTER_IN, g_REGISTER_OUT and g_WRITE_FIRST.
// Each configuration writes every address five times and reads it back.

`timescale 1ns/1ps

module ram_tb;

  localparam int c_N_WORDS    = 32;
  localparam int c_DATA_WIDTH = 8;
  localparam int c_ADDR_W     = colibri_utils::downto_width(colibri_utils::log2ceil(c_N_WORDS));
  localparam int c_N_CFG      = 8;

  logic clk = 1'b0;
  always #2.5 clk = ~clk;

  bit [c_N_CFG-1:0] done;

  initial begin
    wait (&done);
    $display("PASS ram_tb");
    $finish;
  end

  initial begin
    #500_000;
    if (!(&done))
      $fatal(1, "ram_tb: timeout done %b", done);
  end

  for (genvar gi = 0; gi < 2; gi++) begin : gen_rin
    for (genvar go = 0; go < 2; go++) begin : gen_rout
      for (genvar gw = 0; gw < 2; gw++) begin : gen_wf
        localparam int c_IDX = gi * 4 + go * 2 + gw;
        localparam bit g_REGISTER_IN  = (gi == 1);
        localparam bit g_REGISTER_OUT = (go == 1);
        localparam bit g_WRITE_FIRST  = (gw == 1);

        logic reset = 1'b1;
        logic we = 1'b0;
        logic [c_ADDR_W-1:0] addr = '0;
        logic [c_DATA_WIDTH-1:0] data = '0;
        logic [c_DATA_WIDTH-1:0] q;
        int bin_wr;
        int bin_rd;
        int addr_hit [0:c_N_WORDS-1];

        ram #(
          .g_N_WORDS(c_N_WORDS),
          .g_DATA_WIDTH(c_DATA_WIDTH),
          .g_REGISTER_IN(g_REGISTER_IN),
          .g_REGISTER_OUT(g_REGISTER_OUT),
          .g_WRITE_FIRST(g_WRITE_FIRST)
        ) dut (
          .clk_i(clk),
          .reset_i(reset),
          .addr_i(addr),
          .we_i(we),
          .data_i(data),
          .q_o(q)
        );

        task automatic tick();
          @(posedge clk);
          #1;
          if (we)
            bin_wr++;
          else
            bin_rd++;
          addr_hit[int'(addr)]++;
        endtask

        initial begin
          bin_wr = 0;
          bin_rd = 0;
          for (int i = 0; i < c_N_WORDS; i++)
            addr_hit[i] = 0;
          repeat (3) @(posedge clk);
          @(negedge clk);
          reset = 1'b0;
          @(posedge clk);

          for (int pass = 0; pass < 5; pass++) begin
            for (int a = 0; a < c_N_WORDS; a++) begin
              logic [c_DATA_WIDTH-1:0] v_data;
              v_data = c_DATA_WIDTH'($urandom_range(0, 255));
              @(negedge clk);
              addr = c_ADDR_W'(a);
              data = v_data;
              we   = 1'b1;
              tick();
              @(negedge clk);
              we = 1'b0;
              if (g_REGISTER_IN)
                tick();
              if (!g_WRITE_FIRST)
                tick();
              @(negedge clk);
              addr = c_ADDR_W'(a);
              if (g_REGISTER_OUT)
                tick();
              else
                #0.5;
              if (q !== v_data)
                $fatal(1, "ram_tb cfg %0d addr %0d got %h exp %h (rin %0d rout %0d wf %0d)",
                       c_IDX, a, q, v_data, g_REGISTER_IN, g_REGISTER_OUT, g_WRITE_FIRST);
              if (!g_REGISTER_OUT)
                tick();
            end
          end

          if ((bin_wr < c_N_WORDS) || (bin_rd < c_N_WORDS))
            $fatal(1, "ram_tb cfg %0d write/read bins %0d %0d", c_IDX, bin_wr, bin_rd);
          for (int a = 0; a < c_N_WORDS; a++) begin
            if (addr_hit[a] < 5)
              $fatal(1, "ram_tb cfg %0d addr %0d covered %0d", c_IDX, a, addr_hit[a]);
          end
          done[c_IDX] = 1'b1;
        end
      end
    end
  end

endmodule
