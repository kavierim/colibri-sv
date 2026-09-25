// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// I2C Master Controller module
// Author: Alberto Perro (alberto.perro at cern.ch)
// Date: 20-03-2024
// Version: 0.1
//
// This module implements a simple I2C controller.
// Release log:
// - 0.1 first release

`timescale 1ns/1ps

/* verilator lint_off MULTITOP */
module i2c_controller #(
  parameter time g_CLOCK_PERIOD = time'(10ns),
  parameter time g_I2C_PERIOD = time'(10us)
) (
  input  logic       clk_i,
  input  logic       reset_i,
  // I2C controller. SDA is already split; it is not a true inout.
  output logic       scl_o,
  input  logic       sda_i,
  output logic       sda_o,
  output logic       sda_en_o,
  // AXIS command/write
  input  logic [7:0] cmd_data_i,
  input  logic [6:0] cmd_address_i,
  input  logic       cmd_valid_i,
  output logic       cmd_error_o,
  output logic       cmd_ready_o,
  input  logic       cmd_read_i,
  // AXIS read
  output logic [7:0] rd_data_o,
  output logic       rd_valid_o,
  input  logic       rd_ready_i
);

  // VHDL integer(g_I2C_PERIOD / g_CLOCK_PERIOD) truncates at 1 fs.
  // A time/time quotient rounds under this toolchain, so the division is done
  // in integer femtoseconds. Both generics stay parameter time.
  localparam longint c_I2C_FS = longint'(g_I2C_PERIOD / 1ps) * 1000;
  localparam longint c_CLK_FS = longint'(g_CLOCK_PERIOD / 1ps) * 1000;
  localparam int c_SCL_CYCLES = int'(c_I2C_FS / c_CLK_FS);
  localparam int c_SCL_W = colibri_utils::downto_width(c_SCL_CYCLES);
  localparam int c_SDA_PHASE = c_SCL_W / 4;

  typedef enum logic [3:0] {
    S_RESET   = 4'd0,
    S_IDLE    = 4'd1,
    S_START   = 4'd2,
    S_CMD     = 4'd3,
    S_CMD_ACK = 4'd4,
    S_TX      = 4'd5,
    S_TX_ACK  = 4'd6,
    S_STOP    = 4'd7,
    S_RX      = 4'd8,
    S_RX_ACK  = 4'd9
  } fsm_t;

  // VHDL record field `byte` is data_byte: `byte` is a SystemVerilog keyword.
  typedef struct packed {
    fsm_t        state;
    fsm_t        next_state;
    logic        scl_en;
    logic        sda;
    logic        sda_en;
    logic        sda_clk_r;
    logic        rw;
    logic        valid;
    logic        nack;
    logic [31:0] bit_cnt;
    logic [7:0]  addr_rw;
    logic [7:0]  addr_rw_reg;
    logic [7:0]  data_byte;
    logic [7:0]  data_buff;
  } sig_t;

  localparam sig_t c_FSM_RESET = '{
    state:       S_RESET,
    next_state:  S_IDLE,
    scl_en:      1'b0,
    sda:         1'b1,
    sda_en:      1'b0,
    sda_clk_r:   1'b0,
    rw:          1'b0,
    valid:       1'b0,
    nack:        1'b0,
    bit_cnt:     '0,
    addr_rw:     '0,
    addr_rw_reg: '0,
    data_byte:   '0,
    data_buff:   '0
  };

  sig_t rreg = c_FSM_RESET;
  sig_t rcmb;

  // SDC constraints for Altera
  // SDC constraints for Xilinx
  (* preserve = "TRUE" *)
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION \"FORCED IF ASYNCHRONOUS\"" *)
  (* async_reg = "TRUE" *)
  logic sda_d;
  logic sda_reg;

  logic sda_clk;
  logic sda_rising_edge;
  logic sda_falling_edge;
  logic scl_clk;

  // VHDL process variables. They hold state, so they are registers.
  // Nonblocking updates match the VHDL reads, which all use the pre-update value.
  int v_count = 0;
  logic [c_SCL_W-1:0] v_scl_delay = '0;

  always_ff @(posedge clk_i) begin : proc_sync_sda
    if (reset_i) begin
      sda_d   <= 1'b0;
      sda_reg <= 1'b0;
    end else begin
      sda_d   <= sda_i;
      sda_reg <= sda_d;
    end
  end

  // Open-drain SCL with an external pull-up. Verilator is 2-state and turns
  // Z into 0, which would hold SCL low, so the released level is driven high.
  `ifdef VERILATOR
    assign scl_o = (rreg.scl_en && !scl_clk) ? 1'b0 : 1'b1;
  `else
    assign scl_o = (rreg.scl_en && !scl_clk) ? 1'b0 : 1'bz;
  `endif
  assign sda_o    = rreg.sda;
  assign sda_en_o = rreg.sda_en;

  // generate scl and data clocks
  always_ff @(posedge clk_i) begin : proc_clk_generator
    if (reset_i) begin
      v_scl_delay      <= '0;
      scl_clk          <= 1'b0;
      sda_clk          <= 1'b0;
      sda_rising_edge  <= 1'b0;
      sda_falling_edge <= 1'b0;
      v_count          <= 0;
    end else begin
      scl_clk <= v_scl_delay[0];
      sda_clk <= v_scl_delay[c_SDA_PHASE];
      // drive rising edge pulse
      if (!sda_clk && v_scl_delay[c_SDA_PHASE])
        sda_rising_edge <= 1'b1;
      else
        sda_rising_edge <= 1'b0;
      if (sda_clk && !v_scl_delay[c_SDA_PHASE])
        sda_falling_edge <= 1'b1;
      else
        sda_falling_edge <= 1'b0;
      // drive scl clock
      if (v_count < c_SCL_CYCLES / 2)
        v_scl_delay <= {1'b1, v_scl_delay[c_SCL_W-1:1]};
      else
        v_scl_delay <= {1'b0, v_scl_delay[c_SCL_W-1:1]};
      // internal counter for clock division
      if (v_count == c_SCL_CYCLES - 1)
        v_count <= 0;
      else
        v_count <= v_count + 1;
    end
  end

  // main FSM process
  always_comb begin : proc_fsm_cmb
    sig_t v_int;
    v_int       = rreg;
    cmd_ready_o = 1'b0;

    case (rreg.state)
      S_RESET: begin
        v_int.valid  = 1'b0;
        v_int.sda    = 1'b1;
        v_int.sda_en = 1'b0;
        v_int.scl_en = 1'b0;
        v_int.nack   = 1'b0;
        if (sda_falling_edge)
          v_int.state = S_IDLE;
      end

      S_IDLE: begin
        v_int.sda    = 1'b1;
        v_int.sda_en = 1'b0;
        v_int.scl_en = 1'b0;
        if (!v_int.valid) begin
          if (sda_rising_edge) begin
            cmd_ready_o = 1'b1;
            if (cmd_valid_i) begin
              v_int.addr_rw     = {cmd_address_i, cmd_read_i};
              v_int.addr_rw_reg = {cmd_address_i, cmd_read_i};
              v_int.rw          = cmd_read_i;
              v_int.data_byte   = cmd_data_i;
              v_int.state       = S_START;
            end
          end
        end
      end

      S_START: begin
        v_int.sda_en = 1'b1;
        v_int.sda    = sda_clk;
        if (sda_rising_edge) begin
          v_int.sda      = rreg.addr_rw[7];
          v_int.addr_rw  = {rreg.addr_rw[6:0], 1'b0};
          v_int.bit_cnt  = rreg.bit_cnt + 32'(1);
          v_int.state    = S_CMD;
        end
        if (sda_falling_edge) begin
          if (!rreg.scl_en) begin
            v_int.scl_en = 1'b1;
            v_int.nack   = 1'b0;
          end
        end
      end

      S_CMD: begin
        if (sda_rising_edge) begin
          v_int.sda     = rreg.addr_rw[7];
          v_int.addr_rw = {rreg.addr_rw[6:0], 1'b0};
          v_int.bit_cnt = rreg.bit_cnt + 32'(1);
          if (v_int.bit_cnt == 32'd9) begin
            v_int.bit_cnt = '0;
            v_int.sda     = 1'b1;
            v_int.sda_en  = 1'b0;
            v_int.state   = S_CMD_ACK;
          end
        end
      end

      S_CMD_ACK: begin
        if (sda_rising_edge) begin
          if (!rreg.rw) begin
            v_int.sda_en    = 1'b1;
            v_int.sda       = rreg.data_byte[7];
            v_int.data_byte = {rreg.data_byte[6:0], 1'b0};
            v_int.bit_cnt   = rreg.bit_cnt + 32'(1);
            v_int.state     = S_TX;
          end else begin
            v_int.sda       = 1'b1;
            v_int.sda_en    = 1'b0;
            v_int.bit_cnt   = '0;
            v_int.state     = S_RX;
            v_int.data_byte = '0;
          end
        end
        if (sda_falling_edge) begin
          if (sda_reg != 1'b0)
            v_int.nack = 1'b1;
        end
      end

      S_TX: begin
        if (sda_rising_edge) begin
          v_int.sda       = rreg.data_byte[7];
          v_int.data_byte = {rreg.data_byte[6:0], 1'b0};
          v_int.bit_cnt   = rreg.bit_cnt + 32'(1);
          if (v_int.bit_cnt == 32'd9) begin
            v_int.bit_cnt = '0;
            v_int.sda     = 1'b1;
            v_int.sda_en  = 1'b0;
            v_int.state   = S_TX_ACK;
          end
        end
      end

      S_TX_ACK: begin
        if (sda_rising_edge) begin
          cmd_ready_o = 1'b1;
          if (cmd_valid_i) begin
            v_int.addr_rw     = {cmd_address_i, cmd_read_i};
            v_int.addr_rw_reg = {cmd_address_i, cmd_read_i};
            v_int.rw          = cmd_read_i;
            v_int.data_byte   = cmd_data_i;
            if (v_int.addr_rw_reg == rreg.addr_rw_reg) begin
              v_int.sda       = v_int.data_byte[7];
              v_int.data_byte = {v_int.data_byte[6:0], 1'b0};
              v_int.bit_cnt   = v_int.bit_cnt + 32'(1);
              v_int.sda_en    = 1'b1;
              v_int.state     = S_TX;
            end else begin
              v_int.state = S_START;
            end
          end else begin
            v_int.state = S_STOP;
          end
        end
        if (sda_falling_edge) begin
          if (sda_reg != 1'b0)
            v_int.nack = 1'b1;
        end
      end

      S_RX: begin
        if (sda_rising_edge) begin
          v_int.bit_cnt = v_int.bit_cnt + 32'(1);
          if (v_int.bit_cnt == 32'd8) begin
            v_int.valid   = 1'b1;
            v_int.bit_cnt = '0;
            v_int.state   = S_RX_ACK;
          end else begin
            v_int.data_byte = {rreg.data_byte[6:0], 1'b0};
          end
        end
        if (sda_falling_edge) begin
          v_int.data_byte[0] = sda_reg;
          if (rreg.bit_cnt == 32'd7) begin
            cmd_ready_o  = 1'b1;
            v_int.sda    = 1'b1;
            v_int.sda_en = 1'b1;
            if (cmd_valid_i) begin
              v_int.addr_rw     = {cmd_address_i, cmd_read_i};
              v_int.addr_rw_reg = {cmd_address_i, cmd_read_i};
              v_int.rw          = cmd_read_i;
              v_int.data_buff   = cmd_data_i;
              if (v_int.addr_rw_reg == rreg.addr_rw_reg) begin
                v_int.sda        = 1'b0;
                v_int.next_state = S_RX;
              end else begin
                v_int.next_state = S_START;
              end
            end else begin
              v_int.next_state = S_STOP;
            end
          end
        end
      end

      S_RX_ACK: begin
        if (sda_rising_edge) begin
          v_int.sda    = 1'b1;
          v_int.sda_en = 1'b0;
          if (!v_int.valid) begin
            v_int.state     = rreg.next_state;
            v_int.data_byte = rreg.data_buff;
          end else begin
            v_int.state = S_STOP;
          end
        end
      end

      S_STOP: begin
        v_int.sda = ~(sda_clk & v_int.sda_clk_r);
        if (sda_rising_edge)
          v_int.state = S_IDLE;
        if (sda_falling_edge)
          v_int.scl_en = 1'b0;
      end

      default: begin
      end
    endcase

    // consume read
    if (rreg.valid && rd_ready_i)
      v_int.valid = 1'b0;

    if (reset_i)
      v_int = c_FSM_RESET;

    v_int.sda_clk_r = sda_clk;
    rcmb            = v_int;
  end

  assign rd_data_o   = rreg.data_byte;
  assign rd_valid_o  = rreg.valid;
  assign cmd_error_o = rreg.nack;

  always_ff @(posedge clk_i) begin : proc_rreg
    rreg <= rcmb;
  end

endmodule
