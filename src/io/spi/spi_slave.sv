// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Serial Peripheral Interface Slave
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 31-01-2025
// Version: 0.1
//
// 0.1 initial release

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module spi_slave #(
  parameter int unsigned g_WORD_SIZE = 8,
  parameter logic g_SCK_POLARITY = 1'b0,  // 0 -> active high
  parameter logic g_SCK_PHASE = 1'b0      // 0 -> rising edge
) (
  input  logic                       clk_i,
  // SPI
  output logic                       miso_o,  // Master In Slave Out
  input  logic                       mosi_i,  // Master Out Slave In
  input  logic                       cs_n_i,  // Chip Select (active low)
  input  logic                       sck_i,   // SPI clock
  // stream out
  output logic [g_WORD_SIZE-1:0]     src_data_o,
  output logic                       src_valid_o,
  // stream in
  input  logic [g_WORD_SIZE-1:0]     snk_data_i,
  input  logic                       snk_valid_i,
  output logic                       snk_ready_o
);

  typedef struct packed {
    logic mosi;
    logic cs_n;
    logic sck;
  } spi_t;

  typedef enum logic [1:0] {
    S_IDLE        = 2'd0,
    S_SELECT      = 2'd1,
    S_TRANSACTION = 2'd2,
    S_DESELECT    = 2'd3
  } fsm_t;

  typedef struct packed {
    fsm_t                      state;
    logic [g_WORD_SIZE-1:0]    oshift;  // mosi
    logic [g_WORD_SIZE-1:0]    odata;   // reg
    logic [g_WORD_SIZE-1:0]    ishift;  // miso
    logic                      sck;
    logic [31:0]               count;
    logic                      valid;
    logic                      ready;
  } sig_t;

  localparam sig_t c_FSM_INIT = '{
    state:  S_IDLE,
    oshift: '0,
    odata:  '0,
    ishift: '0,
    sck:    1'b0,
    count:  '0,
    valid:  1'b0,
    ready:  1'b0
  };

  spi_t spi_if;
  logic sck_sync;
  sig_t rcmb;
  sig_t rreg = c_FSM_INIT;

  // synchronizers for the inputs
  synchro #(
    .g_DATA_LENGTH(1),
    .g_INIT_VALUE(1'b1)
  ) cs_synchro_inst (
    .clk_i(clk_i),
    .reset_i(1'b0),
    .data_i(cs_n_i),
    .data_o(spi_if.cs_n)
  );

  // SPI clock synchronizer
  synchro #(
    .g_DATA_LENGTH(1),
    .g_INIT_VALUE(g_SCK_POLARITY)
  ) sck_synchro_inst (
    .clk_i(clk_i),
    .reset_i(1'b0),
    .data_i(sck_i),
    .data_o(sck_sync)
  );

  // invert SPI clock if required
  assign spi_if.sck = g_SCK_POLARITY ? ~sck_sync : sck_sync;

  synchro #(
    .g_DATA_LENGTH(1)
  ) mosi_synchro_inst (
    .clk_i(clk_i),
    .reset_i(1'b0),
    .data_i(mosi_i),
    .data_o(spi_if.mosi)
  );

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

  // main fsm
  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int       = rreg;
    v_int.sck   = spi_if.sck;
    v_int.valid = 1'b0;

    case (rreg.state)
      S_IDLE: begin
        v_int.count = '0;
        v_int.ready = 1'b1;
        // save input
        if ((snk_valid_i || !spi_if.cs_n) && rreg.ready) begin
          v_int.ready  = 1'b0;
          v_int.ishift = snk_data_i;
          v_int.state  = S_SELECT;
        end
      end

      S_SELECT: begin
        // transaction start
        if (!spi_if.cs_n) begin
          if (g_SCK_PHASE == 1'b0) begin
            v_int.state = S_TRANSACTION;
          end else if (v_int.sck && !rreg.sck) begin
            v_int.state = S_TRANSACTION;
          end
        end
      end

      S_TRANSACTION: begin
        // rising edge of sck
        if (v_int.sck && !rreg.sck) begin
          if (g_SCK_PHASE == 1'b1) begin
            // VHDL: rreg.ishift(g_WORD_SIZE-2 downto 0) & '0'
            v_int.ishift = rreg.ishift << 1;
            if (rreg.count < 32'(g_WORD_SIZE - 1)) begin
              v_int.count = rreg.count + 32'(1);
            end else begin
              // last bit received
              v_int.state = S_DESELECT;
              v_int.odata = rreg.oshift;
              v_int.valid = 1'b1;
            end
          end else begin
            // VHDL: rreg.oshift(g_WORD_SIZE-2 downto 0) & spi_if.mosi
            v_int.oshift = (rreg.oshift << 1) | g_WORD_SIZE'(spi_if.mosi);
          end
        end

        // falling edge of sck
        if (!v_int.sck && rreg.sck) begin
          if (g_SCK_PHASE == 1'b0) begin
            v_int.ishift = rreg.ishift << 1;
            if (rreg.count < 32'(g_WORD_SIZE - 1)) begin
              v_int.count = rreg.count + 32'(1);
            end else begin
              v_int.state = S_DESELECT;
              v_int.odata = rreg.oshift;
              v_int.valid = 1'b1;
            end
          end else begin
            v_int.oshift = (rreg.oshift << 1) | g_WORD_SIZE'(spi_if.mosi);
            // last shift in
            if (rreg.count == 32'(g_WORD_SIZE - 1)) begin
              v_int.state = S_DESELECT;
              v_int.odata = v_int.oshift;
              v_int.valid = 1'b1;
            end
          end
        end
      end

      S_DESELECT: begin
        // wait for cs_n to be deasserted
        v_int.valid = 1'b0;
      end

      default: begin
      end
    endcase

    if (spi_if.cs_n)
      v_int = c_FSM_INIT;

    rcmb = v_int;
  end

  // output wiring
  assign src_data_o  = rreg.odata;
  assign src_valid_o = rreg.valid;
  assign snk_ready_o = rreg.ready;
  assign miso_o      = rreg.ishift[g_WORD_SIZE-1];

endmodule
