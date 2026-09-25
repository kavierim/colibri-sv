// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Serial Peripheral Interface Master
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 05-02-2025
// Version: 0.1
//
// 0.1 initial release

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module spi_master #(
  // VHDL leaves g_CLOCK_PERIOD with no default. Elaborating this module on
  // its own requires one. 25 ns is 1 sec / 40 MHz, the upstream test harness.
  parameter time g_CLOCK_PERIOD = time'(25ns),
  parameter int unsigned g_SCK_FREQUENCY = 1_000_000,  // spi clock frequency
  parameter int unsigned g_WORD_SIZE = 8,
  parameter logic g_SCK_POLARITY = 1'b0,  // 0 -> active high
  parameter logic g_SCK_PHASE = 1'b0      // 0 -> rising edge
) (
  input  logic                   clk_i,
  // SPI
  input  logic                   miso_i,  // Master In Slave Out
  output logic                   mosi_o,  // Master Out Slave In
  output logic                   cs_n_o,  // Chip Select (active low)
  output logic                   sck_o,   // SPI clock
  // stream out
  output logic [g_WORD_SIZE-1:0] src_data_o,
  output logic                   src_valid_o,
  // stream in
  input  logic [g_WORD_SIZE-1:0] snk_data_i,
  input  logic                   snk_valid_i,
  output logic                   snk_ready_o
);

  // VHDL integer((1 sec / g_SCK_FREQUENCY) / g_CLOCK_PERIOD) truncates at 1 fs.
  // A time/time quotient rounds under this toolchain, so the division is done
  // in integer femtoseconds. g_CLOCK_PERIOD stays parameter time.
  localparam longint c_CLK_FS = longint'(g_CLOCK_PERIOD / 1ps) * 1000;
  localparam int c_SCK_DIV =
    int'((64'sd1_000_000_000_000_000 / longint'(g_SCK_FREQUENCY)) / c_CLK_FS);

  typedef struct packed {
    logic cs_n;
    logic sck;
  } spi_t;

  localparam spi_t c_SPI_DEFAULT = '{
    cs_n: 1'b1,
    sck:  g_SCK_POLARITY
  };

  typedef enum logic [1:0] {
    S_IDLE        = 2'd0,
    S_SELECT      = 2'd1,
    S_TRANSACTION = 2'd2,
    S_DESELECT    = 2'd3
  } fsm_t;

  typedef struct packed {
    fsm_t                   state;
    logic [g_WORD_SIZE-1:0] oshift;  // mosi
    logic [g_WORD_SIZE-1:0] odata;   // reg
    logic [g_WORD_SIZE-1:0] ishift;  // miso
    logic [31:0]            clkcnt;
    logic [31:0]            bitcnt;
    spi_t                   spi;
    logic                   valid;
    logic                   ready;
  } sig_t;

  localparam sig_t c_FSM_INIT = '{
    state:  S_IDLE,
    oshift: '0,
    odata:  '0,
    ishift: '0,
    clkcnt: '0,
    bitcnt: '0,
    spi:    c_SPI_DEFAULT,
    valid:  1'b0,
    ready:  1'b0
  };

  logic spi_miso;
  sig_t rcmb;
  sig_t rreg = c_FSM_INIT;

  // MISO synchronizer
  synchro #(
    .g_DATA_LENGTH(1)
  ) miso_synchro_inst (
    .clk_i(clk_i),
    .reset_i(1'b0),
    .data_i(miso_i),
    .data_o(spi_miso)
  );

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

  // main fsm
  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int       = rreg;
    v_int.valid = 1'b0;

    // sck clock division counter
    if (rreg.clkcnt < 32'(c_SCK_DIV / 2 - 1)) begin
      v_int.clkcnt = rreg.clkcnt + 32'(1);
    end else begin
      v_int.spi.sck = ~rreg.spi.sck;
      v_int.clkcnt  = '0;
    end

    case (rreg.state)
      S_IDLE: begin
        v_int.bitcnt   = '0;
        v_int.ready    = 1'b1;
        v_int.spi.cs_n = 1'b1;
        // keep the spi clock off
        v_int.spi.sck  = 1'b0;
        v_int.clkcnt   = '0;

        // save input
        if (snk_valid_i && rreg.ready) begin
          v_int.ready  = 1'b0;
          v_int.ishift = snk_data_i;
          if (g_SCK_PHASE == 1'b0)
            v_int.state = S_TRANSACTION;
          else
            v_int.state = S_SELECT;
          v_int.spi.cs_n = 1'b0;
        end
      end

      S_SELECT: begin
        // transaction start
        // rising edge spi clock
        if (v_int.spi.sck && !rreg.spi.sck)
          v_int.state = S_TRANSACTION;
      end

      S_TRANSACTION: begin
        // rising edge of sck
        if (v_int.spi.sck && !rreg.spi.sck) begin
          if (g_SCK_PHASE == 1'b1) begin
            // VHDL: rreg.ishift(g_WORD_SIZE-2 downto 0) & '0'
            v_int.ishift = rreg.ishift << 1;
            if (rreg.bitcnt < 32'(g_WORD_SIZE - 1)) begin
              v_int.bitcnt = rreg.bitcnt + 32'(1);
            end else begin
              // last bit received
              v_int.state   = S_DESELECT;
              v_int.odata   = rreg.oshift;
              v_int.valid   = 1'b1;
              // stop the clock
              v_int.clkcnt  = '0;
              v_int.spi.sck = 1'b0;
            end
          end else begin
            // VHDL: rreg.oshift(g_WORD_SIZE-2 downto 0) & spi_miso
            v_int.oshift = (rreg.oshift << 1) | g_WORD_SIZE'(spi_miso);
          end
        end

        // falling edge of sck
        if (!v_int.spi.sck && rreg.spi.sck) begin
          if (g_SCK_PHASE == 1'b0) begin
            v_int.ishift = rreg.ishift << 1;
            if (rreg.bitcnt < 32'(g_WORD_SIZE - 1)) begin
              v_int.bitcnt = rreg.bitcnt + 32'(1);
            end else begin
              v_int.state   = S_DESELECT;
              v_int.odata   = rreg.oshift;
              v_int.valid   = 1'b1;
              // stop the clock
              v_int.clkcnt  = '0;
              v_int.spi.sck = 1'b0;
            end
          end else begin
            v_int.oshift = (rreg.oshift << 1) | g_WORD_SIZE'(spi_miso);
          end
        end
      end

      S_DESELECT: begin
        // disable cs
        v_int.spi.cs_n = 1'b1;
        v_int.valid    = 1'b0;
        // keep clock off
        v_int.clkcnt   = '0;
        v_int.spi.sck  = 1'b0;
        v_int.state    = S_IDLE;
      end

      default: begin
      end
    endcase

    rcmb = v_int;
  end

  // output wiring
  assign src_data_o  = rreg.odata;
  assign src_valid_o = rreg.valid;
  assign snk_ready_o = rreg.ready;
  assign mosi_o      = rreg.ishift[g_WORD_SIZE-1];
  assign sck_o       = (g_SCK_POLARITY == 1'b0) ? rreg.spi.sck : ~rreg.spi.sck;
  assign cs_n_o      = rreg.spi.cs_n;

endmodule
