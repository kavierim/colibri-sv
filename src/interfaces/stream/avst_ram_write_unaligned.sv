// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Avalon Stream to RAM writer with unaligned (byte-addressable) access.
// Writes Avalon-ST packets to a word-addressed RAM with a byte-enable vector.
// start_addr_i is the initial byte address at start of packet. An extra write
// after end of packet can deassert snk_ready_o for one cycle. RAM outputs are
// delayed by 2 cycles. flush_i writes any bytes still in the buffer.

`timescale 1ns/1ps

module avst_ram_write_unaligned #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 16,
  localparam int c_DATA_W        = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W       = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_BYTE_ADDR_RAW = colibri_utils::log2ceil(int'(g_RAM_DEPTH) * int'(g_WORD_BYTES)),
  localparam int c_BYTE_ADDR_W   = colibri_utils::downto_width(c_BYTE_ADDR_RAW),
  localparam int c_ADDR_RAW      = colibri_utils::log2ceil(int'(g_RAM_DEPTH)),
  localparam int c_ADDR_W        = colibri_utils::downto_width(c_ADDR_RAW),
  localparam int c_BUF_W         = 2 * c_DATA_W,
  localparam int c_DIV_W         = colibri_utils::maximum(c_BYTE_ADDR_W, 32)
) (
  input  logic                       clk_i,
  input  logic                       reset_i,
  input  logic [c_DATA_W-1:0]        snk_data_i,
  input  logic [c_EMPTY_W-1:0]       snk_empty_i,
  input  logic                       snk_sop_i,
  input  logic                       snk_eop_i,
  input  logic                       snk_valid_i,
  output logic                       snk_ready_o,
  input  logic [c_BYTE_ADDR_W-1:0]   start_addr_i,
  input  logic                       flush_i,
  output logic [g_WORD_BYTES-1:0]    wr_be_o,
  output logic [c_ADDR_W-1:0]        wr_addr_o,
  output logic [c_DATA_W-1:0]        wr_data_o
);

  typedef enum logic [1:0] {
    S_IDLE  = 2'd0,
    S_SOP   = 2'd1,
    S_WRITE = 2'd2,
    S_EOP   = 2'd3
  } state_t;

  typedef struct packed {
    logic [g_WORD_BYTES-1:0] be;
    logic [c_ADDR_W-1:0]     addr;
    logic [c_DATA_W-1:0]     data;
  } ram_wr_t;

  typedef struct packed {
    state_t                  state;
    logic                    snk_ready;
    logic                    snk_eop;
    int                      buf_bytes;
    int                      byte_skew;
    logic                    buf_valid;
    logic [c_BUF_W-1:0]      buf_data;
    logic [c_ADDR_W-1:0]     start_addr;
    ram_wr_t                 ram_wr;
    logic                    packet_active;
  } reg_t;

  localparam ram_wr_t c_RAM_WR_INIT = '{be: '0, addr: '0, data: '0};
  localparam reg_t c_REG_TYPE_INIT = '{
    state:         S_IDLE,
    snk_ready:     1'b0,
    snk_eop:       1'b0,
    buf_bytes:     0,
    byte_skew:     0,
    buf_valid:     1'b0,
    buf_data:      '0,
    start_addr:    '0,
    ram_wr:        c_RAM_WR_INIT,
    packet_active: 1'b0
  };

  reg_t r /* verilator public */ = c_REG_TYPE_INIT;
  reg_t rin;

  task automatic start_of_packet(inout reg_t v);
    v.start_addr = c_ADDR_W'(c_DIV_W'(start_addr_i) / c_DIV_W'(g_WORD_BYTES));
    v.byte_skew  = int'(c_DIV_W'(start_addr_i) % c_DIV_W'(g_WORD_BYTES));
    v.state      = S_SOP;
    if (snk_eop_i) begin
      v.snk_ready = colibri_types::bool_to_sl(bit'(
        (int'(g_WORD_BYTES) - int'(snk_empty_i) + v.byte_skew) <= int'(g_WORD_BYTES)
      ));
    end
  endtask

  task automatic end_of_packet(inout reg_t v);
    v.snk_ready = colibri_types::bool_to_sl(bit'(
      (v.buf_bytes + int'(g_WORD_BYTES) - int'(snk_empty_i)) <= int'(g_WORD_BYTES)
    ));
    v.state = S_EOP;
  endtask

  // Two-process structure.
  always_comb begin : proc_comb
    reg_t v;
    v = r;

    v.snk_ready = 1'b1;
    v.buf_valid = 1'b0;
    v.snk_eop   = snk_eop_i;

    case (r.state)
      S_IDLE: begin
        v.ram_wr    = c_RAM_WR_INIT;
        v.byte_skew = 0;
        if (snk_valid_i && snk_sop_i && r.snk_ready)
          start_of_packet(v);
      end

      S_SOP: begin
        // VHDL assigns be(left - i), so byte i lands in the opposite bit.
        for (int i = 0; i < int'(g_WORD_BYTES); i++) begin
          v.ram_wr.be[int'(g_WORD_BYTES) - 1 - i] = colibri_types::bool_to_sl(
            bit'((i >= r.byte_skew) && (i < (r.byte_skew + r.buf_bytes)))
          );
        end
        v.ram_wr.addr = r.start_addr;
        v.ram_wr.data = r.buf_data[(r.byte_skew * int'(g_BYTE_WIDTH)) +: c_DATA_W];

        if ((r.buf_bytes + r.byte_skew) <= int'(g_WORD_BYTES)) begin
          v.buf_bytes = 0;
          if (snk_valid_i && snk_sop_i && r.snk_ready)
            start_of_packet(v);
          else
            v.state = S_IDLE;
        end else begin
          v.buf_bytes = r.buf_bytes + r.byte_skew - int'(g_WORD_BYTES);
        end

        if (r.snk_eop || flush_i) begin
          if ((r.buf_bytes + r.byte_skew) > int'(g_WORD_BYTES)) begin
            v.buf_data = {r.buf_data[c_DATA_W-1:0], {c_DATA_W{1'b0}}};
            v.state    = S_EOP;
          end
        end else if (snk_eop_i && snk_valid_i) begin
          end_of_packet(v);
        end else begin
          v.state = S_WRITE;
        end
      end

      S_WRITE: begin
        if (r.buf_valid) begin
          v.ram_wr = '{
            be:   {g_WORD_BYTES{1'b1}},
            addr: r.ram_wr.addr + c_ADDR_W'(1),
            data: r.buf_data[(r.byte_skew * int'(g_BYTE_WIDTH)) +: c_DATA_W]
          };
          v.buf_bytes = r.buf_bytes - int'(g_WORD_BYTES);
        end else begin
          v.ram_wr.be = '0;
        end

        if (snk_eop_i && snk_valid_i)
          end_of_packet(v);

        if (flush_i) begin
          v.buf_bytes = r.byte_skew;
          v.buf_data  = {r.buf_data[c_DATA_W-1:0], {c_DATA_W{1'b0}}};
          v.state     = S_EOP;
        end
      end

      S_EOP: begin
        v.ram_wr.addr = r.ram_wr.addr + c_ADDR_W'(1);
        v.ram_wr.data = r.buf_data[(r.byte_skew * int'(g_BYTE_WIDTH)) +: c_DATA_W];

        if (r.buf_bytes > int'(g_WORD_BYTES)) begin
          v.ram_wr.be = {g_WORD_BYTES{1'b1}};
          v.buf_data  = {r.buf_data[c_DATA_W-1:0], {c_DATA_W{1'b0}}};
          v.buf_bytes = r.buf_bytes - int'(g_WORD_BYTES);
        end else begin
          for (int i = 0; i < int'(g_WORD_BYTES); i++) begin
            v.ram_wr.be[int'(g_WORD_BYTES) - 1 - i] = colibri_types::bool_to_sl(
              bit'(i < r.buf_bytes)
            );
          end
          v.buf_bytes = 0;
        end

        if (v.buf_bytes == 0) begin
          if (snk_valid_i && snk_sop_i && r.snk_ready)
            start_of_packet(v);
          else
            v.state = S_IDLE;
        end
      end

      default: begin
        v.state = S_IDLE;
      end
    endcase

    if (snk_valid_i && r.snk_ready) begin
      v.packet_active = r.packet_active | snk_sop_i;
      if (v.packet_active) begin
        v.buf_data  = {v.buf_data[c_DATA_W-1:0], snk_data_i};
        v.buf_bytes = v.buf_bytes + int'(g_WORD_BYTES) - int'(snk_empty_i);
        v.buf_valid = 1'b1;
      end
      if (snk_eop_i)
        v.packet_active = 1'b0;
    end

    if (flush_i)
      v.packet_active = 1'b0;

    if (reset_i)
      v = c_REG_TYPE_INIT;

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_seq
    r <= rin;
  end

  assign snk_ready_o = r.snk_ready;
  assign wr_be_o     = r.ram_wr.be;
  assign wr_addr_o   = r.ram_wr.addr;
  assign wr_data_o   = r.ram_wr.data;

endmodule
