// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Avalon Stream from RAM reader with unaligned (byte-addressable) access.
// start_i begins a read while the component is idle. start_addr_i is a byte
// address and length_i is a byte count. The last beat may be partially empty;
// empty bytes sit at the LSB.

`timescale 1ns/1ps

module avst_ram_read_unaligned #(
  parameter int unsigned g_BYTE_WIDTH = 8,
  // VHDL leaves these without defaults. Verilator elaborates this module on
  // its own, so defaults are required. Instantiations still pass them.
  parameter int unsigned g_WORD_BYTES = 8,
  parameter int unsigned g_RAM_DEPTH  = 16,
  localparam int c_BYTE_ADDR_RAW = colibri_utils::log2ceil(int'(g_RAM_DEPTH) * int'(g_WORD_BYTES)),
  localparam int c_BYTE_ADDR_W   = colibri_utils::downto_width(c_BYTE_ADDR_RAW),
  localparam int c_ADDR_RAW      = colibri_utils::log2ceil(int'(g_RAM_DEPTH)),
  localparam int c_ADDR_W        = colibri_utils::downto_width(c_ADDR_RAW),
  localparam int c_LEN_W         = c_BYTE_ADDR_RAW + 1,
  localparam int c_DATA_W        = int'(g_WORD_BYTES) * int'(g_BYTE_WIDTH),
  localparam int c_EMPTY_W       = colibri_types::avst_empty_width(c_DATA_W, int'(g_BYTE_WIDTH)),
  localparam int c_BUF_W         = 2 * c_DATA_W,
  localparam int c_DIV_W         = colibri_utils::maximum(c_BYTE_ADDR_W, 32)
) (
  input  logic                       clk_i,
  input  logic                       reset_i,
  output logic [c_DATA_W-1:0]        src_data_o,
  output logic [c_EMPTY_W-1:0]       src_empty_o,
  output logic                       src_sop_o,
  output logic                       src_eop_o,
  output logic                       src_valid_o,
  input  logic                       src_ready_i,
  input  logic [c_BYTE_ADDR_W-1:0]   start_addr_i,
  input  logic [c_LEN_W-1:0]         length_i,
  input  logic                       start_i,
  output logic                       busy_o,
  output logic                       rd_en_o,
  output logic [c_ADDR_W-1:0]        rd_addr_o,
  input  logic [c_DATA_W-1:0]        rd_data_i
);

  // Two '::' on a class specialization do not elaborate, so import the class.
  import colibri_types::avst;

  typedef enum logic [2:0] {
    S_IDLE = 3'd0,
    S_INIT = 3'd1,
    S_SOP  = 3'd2,
    S_BODY = 3'd3,
    S_EOP  = 3'd4
  } state_t;

  typedef struct packed {
    logic                en;
    logic [c_ADDR_W-1:0] addr;
  } ram_rd_t;

  `COLIBRI_AVST_MASTER_T(avst_t, c_DATA_W, c_EMPTY_W);

  typedef struct packed {
    state_t              state;
    avst_t               avst_src;
    ram_rd_t             ram_rd;
    logic [c_LEN_W-1:0]  rd_cntdwn;
    logic [c_LEN_W-1:0]  out_cntdwn;
    int                  skew;
    int                  buf_bytes;
    logic [c_BUF_W-1:0]  buf_data;
    logic [c_DATA_W-1:0] rd_data;
    logic                rd_valid;
    logic                ram_valid;
    logic                buf_fill;
  } reg_t;

  localparam ram_rd_t c_RAM_RD_INIT = '{en: 1'b0, addr: '0};

  function automatic avst_t avst_from_init();
    avst#(c_DATA_W, int'(g_BYTE_WIDTH))::master_t v_init;
    avst_t v_avst;
    v_init = avst#(c_DATA_W, int'(g_BYTE_WIDTH))::master_init();
    v_avst.data  = v_init.data;
    v_avst.empty = v_init.empty;
    v_avst.sop   = v_init.sop;
    v_avst.eop   = v_init.eop;
    v_avst.valid = v_init.valid;
    return v_avst;
  endfunction

  function automatic reg_t reg_init();
    reg_t v;
    v            = '0;
    v.state      = S_IDLE;
    v.avst_src   = avst_from_init();
    v.ram_rd     = c_RAM_RD_INIT;
    return v;
  endfunction

  reg_t r   = reg_init();
  reg_t rin;

  // Reads r (the register), matching the VHDL procedure.
  task automatic output_buf_data(inout reg_t v);
    int v_lo;
    v_lo = c_DATA_W - int'(g_BYTE_WIDTH) * r.skew;
    v.avst_src.data = r.buf_data[v_lo +: c_DATA_W];
    v.buf_bytes     = r.buf_bytes - int'(g_WORD_BYTES);
    if (r.out_cntdwn >= c_LEN_W'(g_WORD_BYTES))
      v.out_cntdwn = r.out_cntdwn - c_LEN_W'(g_WORD_BYTES);
    else
      v.out_cntdwn = '0;
  endtask

  // Two-process structure.
  always_comb begin : proc_comb
    reg_t v;
    v = r;

    if (r.avst_src.valid && src_ready_i)
      v.avst_src = avst_from_init();

    case (r.state)
      S_IDLE: begin
        v.ram_rd    = c_RAM_RD_INIT;
        v.buf_bytes = 0;
        if (start_i) begin
          v.ram_rd.en   = 1'b1;
          v.ram_rd.addr = c_ADDR_W'(c_DIV_W'(start_addr_i) / c_DIV_W'(g_WORD_BYTES));
          v.skew        = int'(c_DIV_W'(start_addr_i) % c_DIV_W'(g_WORD_BYTES));
          v.rd_cntdwn   = length_i + c_LEN_W'(v.skew);
          v.out_cntdwn  = length_i;
          v.state       = S_INIT;
        end
      end

      S_INIT: begin
        v.buf_fill = 1'b1;
        if (r.buf_bytes == int'(g_WORD_BYTES)) begin
          v.buf_fill = 1'b0;
          v.state    = S_SOP;
        end
      end

      S_SOP: begin
        if (v.avst_src.valid == 1'b0) begin
          v.avst_src.valid = 1'b1;
          v.avst_src.sop   = 1'b1;
          if (r.out_cntdwn <= c_LEN_W'(g_WORD_BYTES)) begin
            v.avst_src.eop   = 1'b1;
            v.avst_src.empty = c_EMPTY_W'(int'(g_WORD_BYTES) - int'(r.out_cntdwn));
            output_buf_data(v);
            v.state = S_IDLE;
          end else begin
            output_buf_data(v);
            if (v.out_cntdwn <= c_LEN_W'(g_WORD_BYTES)) begin
              if (!r.rd_valid)
                v.buf_data = {v.buf_data[c_DATA_W-1:0], r.rd_data};
              v.state = S_EOP;
            end else begin
              v.state = S_BODY;
            end
          end
        end
      end

      S_BODY: begin
        if (v.avst_src.valid == 1'b0) begin
          v.avst_src.valid = 1'b1;
          output_buf_data(v);
        end
        if (v.out_cntdwn <= c_LEN_W'(g_WORD_BYTES)) begin
          if (!r.rd_valid)
            v.buf_data = {v.buf_data[c_DATA_W-1:0], r.rd_data};
          v.state = S_EOP;
        end
      end

      S_EOP: begin
        if (v.avst_src.valid == 1'b0) begin
          v.avst_src.valid = 1'b1;
          v.avst_src.eop   = 1'b1;
          v.avst_src.empty = c_EMPTY_W'(int'(g_WORD_BYTES) - int'(r.out_cntdwn));
          output_buf_data(v);
          v.state = S_IDLE;
        end
      end

      default: begin
        v.state = S_IDLE;
      end
    endcase

    if ((r.ram_valid == 1'b1) && (r.rd_valid == 1'b0)) begin
      v.rd_data  = rd_data_i;
      v.rd_valid = 1'b1;
    end

    if (((v.rd_valid == 1'b1) || (r.buf_fill == 1'b1)) && (v.buf_bytes <= int'(g_WORD_BYTES))) begin
      v.buf_data  = {v.buf_data[c_DATA_W-1:0], v.rd_data};
      v.buf_bytes = v.buf_bytes + int'(g_WORD_BYTES);
      v.rd_valid  = 1'b0;
    end

    if (r.state != S_IDLE) begin
      if (r.rd_cntdwn > c_LEN_W'(g_WORD_BYTES)) begin
        if (v.rd_valid == 1'b0) begin
          v.rd_cntdwn   = r.rd_cntdwn - c_LEN_W'(g_WORD_BYTES);
          v.ram_rd.en   = 1'b1;
          v.ram_rd.addr = r.ram_rd.addr + c_ADDR_W'(1);
        end else begin
          v.ram_rd.en = 1'b0;
        end
      end else begin
        v.rd_cntdwn = '0;
        v.ram_rd    = c_RAM_RD_INIT;
      end
    end

    v.ram_valid = r.ram_rd.en | r.rd_valid;

    if (reset_i)
      v = reg_init();

    rin = v;
  end

  always_ff @(posedge clk_i) begin : proc_seq
    r <= rin;
  end

  assign src_data_o  = r.avst_src.data;
  assign src_empty_o = r.avst_src.empty;
  assign src_sop_o   = r.avst_src.sop;
  assign src_eop_o   = r.avst_src.eop;
  assign src_valid_o = r.avst_src.valid;
  assign rd_en_o     = r.ram_rd.en;
  assign rd_addr_o   = r.ram_rd.addr;
  assign busy_o      = colibri_types::bool_to_sl(bit'(r.state != S_IDLE));

endmodule
