// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Stream to Wishbone Master Memory Mapped Interface.
// Converts a full duplex stream into a Wishbone.B4 master.
// 0x01 sets the address, 0x02 is a read, 0x03 is a write, 0x00 is NOP.
// Replies use the last command plus 0x10 in the high nibble.

`timescale 1ns/1ps

module stream_to_wbm #(
  parameter int unsigned g_WB_ADDR_WIDTH = 32,
  parameter int unsigned g_WB_DATA_WIDTH = 32
) (
  input  logic clk_i,
  input  logic reset_i,
  input  logic [8 + colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH)) - 1:0] snk_data_i,
  input  logic snk_valid_i,
  output logic snk_ready_o,
  output logic [8 + colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH)) - 1:0] src_data_o,
  output logic src_valid_o,
  output logic [g_WB_ADDR_WIDTH-1:0] wb_adr_o,
  input  logic [g_WB_DATA_WIDTH-1:0] wb_dat_i,
  output logic [g_WB_DATA_WIDTH-1:0] wb_dat_o,
  output logic wb_we_o,
  output logic [colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8)-1:0] wb_sel_o,
  output logic wb_stb_o,
  output logic wb_cyc_o,
  input  logic wb_ack_i,
  input  logic wb_err_i
);

  localparam int c_HDR_WIDTH  = 8;
  localparam int c_DATA_WIDTH = colibri_utils::maximum(int'(g_WB_ADDR_WIDTH), int'(g_WB_DATA_WIDTH));
  localparam int c_STR_WIDTH  = c_DATA_WIDTH + c_HDR_WIDTH;
  localparam int c_SEL_W      = colibri_utils::downto_width(int'(g_WB_DATA_WIDTH) / 8);

  localparam logic [3:0] c_CMD_ADDR  = 4'h1;
  localparam logic [3:0] c_CMD_RDATA = 4'h2;
  localparam logic [3:0] c_CMD_WDATA = 4'h3;
  localparam logic [3:0] c_CMD_ACK   = 4'h1;

  typedef struct {
    logic [g_WB_ADDR_WIDTH-1:0] adr;
    logic [g_WB_DATA_WIDTH-1:0] wdat;
    logic                       we;
    logic                       stb;
    logic                       cyc;
  } wb_slim_t;

  function automatic wb_slim_t wb_rst();
    wb_slim_t v;
    v.adr  = '0;
    v.wdat = '0;
    v.we   = 1'b0;
    v.stb  = 1'b0;
    v.cyc  = 1'b0;
    return v;
  endfunction

  typedef enum logic [1:0] {
    S_IDLE = 2'd0,
    S_REQ  = 2'd1,
    S_ACK  = 2'd2
  } cmd_fsm_t;

  typedef struct {
    cmd_fsm_t              state;
    wb_slim_t              wb;
    logic [c_STR_WIDTH-1:0] rdat;
    logic                  rvalid;
  } cmd_sig_t;

  function automatic cmd_sig_t cmd_init();
    cmd_sig_t v;
    v.state  = S_IDLE;
    v.wb     = wb_rst();
    v.rvalid = 1'b0;
    v.rdat   = '0;
    return v;
  endfunction

  cmd_sig_t rreg;
  cmd_sig_t rcmb;

  logic                  skid_ready;
  logic                  skid_valid;
  logic [c_STR_WIDTH-1:0] skid_data;

  // wb_err_i is an entity port and is unused by the VHDL architecture.
  // verilator lint_off UNUSEDSIGNAL
  wire _unused_ok = wb_err_i;
  // verilator lint_on UNUSEDSIGNAL

  initial rreg = cmd_init();

  // verilator lint_off PINCONNECTEMPTY
  skid_buffer #(
    .g_DATA_WIDTH(c_STR_WIDTH)
  ) skid_buffer_inst (
    .clk_i      (clk_i),
    .reset_i    (reset_i),
    .snk_data_i (snk_data_i),
    .snk_empty_i('0),
    .snk_keep_i ('0),
    .snk_sop_i  (1'b0),
    .snk_eop_i  (1'b0),
    .snk_valid_i(snk_valid_i),
    .snk_ready_o(snk_ready_o),
    .src_data_o (skid_data),
    .src_empty_o(),
    .src_keep_o (),
    .src_sop_o  (),
    .src_eop_o  (),
    .src_valid_o(skid_valid),
    .src_ready_i(skid_ready)
  );
  // verilator lint_on PINCONNECTEMPTY

  always_comb begin : proc_cmd_fsm
    cmd_sig_t v_int;
    v_int        = rreg;
    v_int.rvalid = 1'b0;

    case (rreg.state)
      S_IDLE: begin
        v_int.wb.stb = 1'b0;
        v_int.wb.cyc = 1'b0;
        if (skid_valid) begin
          v_int.rdat = skid_data;
          case (skid_data[c_STR_WIDTH-1 -: c_HDR_WIDTH])
            {4'h0, c_CMD_ADDR}: begin
              v_int.wb.adr = g_WB_ADDR_WIDTH'(skid_data[c_DATA_WIDTH-1:0]);
              v_int.rdat[c_STR_WIDTH-1 -: c_HDR_WIDTH] = {c_CMD_ACK, c_CMD_ADDR};
              v_int.rvalid = 1'b1;
              v_int.state  = S_IDLE;
            end
            {4'h0, c_CMD_RDATA}: begin
              v_int.wb.we = 1'b0;
              v_int.state = S_REQ;
            end
            {4'h0, c_CMD_WDATA}: begin
              v_int.wb.we   = 1'b1;
              v_int.state   = S_REQ;
              v_int.wb.wdat = skid_data[g_WB_DATA_WIDTH-1:0];
            end
            default: v_int.state = S_IDLE;
          endcase
        end
      end
      S_REQ: begin
        v_int.wb.cyc = 1'b1;
        v_int.wb.stb = 1'b1;
        v_int.state  = S_ACK;
      end
      S_ACK: begin
        v_int.wb.stb = 1'b0;
        if (wb_ack_i) begin
          v_int.rvalid = 1'b1;
          if (rreg.wb.we == 1'b0) begin
            v_int.rdat[c_STR_WIDTH-1 -: c_HDR_WIDTH] = {c_CMD_ACK, c_CMD_RDATA};
            v_int.rdat[c_DATA_WIDTH-1:0] = c_DATA_WIDTH'(wb_dat_i);
          end else begin
            v_int.rdat[c_STR_WIDTH-1 -: c_HDR_WIDTH] = {c_CMD_ACK, c_CMD_WDATA};
          end
          v_int.wb    = wb_rst();
          v_int.state = S_IDLE;
        end
      end
      default: v_int.state = S_IDLE;
    endcase

    if (reset_i)
      v_int = cmd_init();
    rcmb = v_int;
  end

  always_ff @(posedge clk_i) begin : proc_cmd_reg
    rreg <= rcmb;
  end

  assign wb_adr_o    = rreg.wb.adr;
  assign wb_dat_o    = rreg.wb.wdat;
  assign wb_we_o     = rreg.wb.we;
  assign wb_sel_o    = {c_SEL_W{1'b1}};
  assign wb_stb_o    = rreg.wb.stb;
  assign wb_cyc_o    = rreg.wb.cyc;
  assign src_data_o  = rreg.rdat;
  assign src_valid_o = rreg.rvalid;
  assign skid_ready  = (rreg.state == S_IDLE);

endmodule
