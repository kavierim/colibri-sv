// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Frequency counter. Measures arbitrary clocks against a known reference
// and returns the frequency in Hz.

`timescale 1ns/1ps

module frequency_counter #(
  // VHDL generic has no default. 100 MHz lets Verilator elaborate this top.
  parameter int unsigned g_CLK_REF_FREQ_HZ = 100_000_000,
  parameter int unsigned g_NUM_CLOCKS     = 1,
  parameter int unsigned g_DATA_WIDTH     = 32,
  parameter int unsigned g_SAMPLE_FREQ_HZ = 1
) (
  input  logic clk_ref_i,
  input  logic reset_i,
  input  logic [g_NUM_CLOCKS-1:0] clk_meas_i,
  output `COLIBRI_UNS_ARRAY(freq_data_o, 0, g_NUM_CLOCKS - 1, g_DATA_WIDTH),
  output logic [g_NUM_CLOCKS-1:0] freq_valid_o
);

  localparam int c_FREQ_DIV = colibri_utils::div_ceil(int'(g_CLK_REF_FREQ_HZ), int'(g_SAMPLE_FREQ_HZ));

  logic capture;
  `COLIBRI_UNS_ARRAY(freq_data_r, 0, g_NUM_CLOCKS - 1, g_DATA_WIDTH);
  logic [g_NUM_CLOCKS-1:0] freq_valid_r;

  // verilator lint_off PINCONNECTEMPTY
  counter #(
    .g_MODULO(c_FREQ_DIV)
  ) ref_counter_inst (
    .clk_i       (clk_ref_i),
    .reset_i     (reset_i),
    .enable_i    (1'b1),
    .value_o     (),
    .wraparound_o(capture)
  );
  // verilator lint_on PINCONNECTEMPTY

  for (genvar i = 0; i < g_NUM_CLOCKS; i++) begin : gen_arb_counters
    logic capture_sync;
    logic freq_valid;
    logic [g_DATA_WIDTH-1:0] freq_data;
    logic [g_DATA_WIDTH-1:0] freq_data_reg;

    synchro_pulse synchro_capture_inst (
      .src_clk_i(clk_ref_i),
      .dst_clk_i(clk_meas_i[i]),
      .pulse_i  (capture),
      .pulse_o  (capture_sync)
    );

    // verilator lint_off PINCONNECTEMPTY
    counter #(
      .g_COUNTER_WIDTH(int'(g_DATA_WIDTH))
    ) arb_counter_inst (
      .clk_i       (clk_meas_i[i]),
      .reset_i     (capture_sync),
      .enable_i    (1'b1),
      .value_o     (freq_data),
      .wraparound_o()
    );
    // verilator lint_on PINCONNECTEMPTY

    always_ff @(posedge clk_meas_i[i]) begin : proc_sync_counter
      freq_valid <= 1'b0;
      if (capture_sync) begin
        freq_data_reg <= freq_data;
        freq_valid    <= 1'b1;
      end
    end

    synchro_pulse synchro_valid_inst (
      .src_clk_i(clk_meas_i[i]),
      .dst_clk_i(clk_ref_i),
      .pulse_i  (freq_valid),
      .pulse_o  (freq_valid_r[i])
    );

    assign freq_data_r[i] = freq_data_reg;
  end

  always_ff @(posedge clk_ref_i) begin : proc_drive_out
    if (reset_i) begin
      for (int k = 0; k < g_NUM_CLOCKS; k++)
        freq_data_o[k] <= '0;
      freq_valid_o <= '0;
    end else begin
      for (int k = 0; k < g_NUM_CLOCKS; k++) begin
        // numeric_std keeps the unsigned width, then the VHDL resizes to 32.
        freq_data_o[k] <= g_DATA_WIDTH'(32'(freq_data_r[k] * g_DATA_WIDTH'(g_SAMPLE_FREQ_HZ)));
      end
      freq_valid_o <= freq_valid_r;
    end
  end

endmodule
