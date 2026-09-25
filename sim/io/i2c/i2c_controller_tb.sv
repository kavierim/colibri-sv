// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// I2C controller scenarios from i2c_controller_tb.vhdl. Ten iterations each:
// byte write, 2-byte read, write-then-read, read-then-write, 3-byte write.
// Slave address is 7'h3B. SDA is open-drain in this testbench.
`timescale 1ns/1ps

module i2c_controller_tb;
  localparam time c_CLK_PERIOD = time'(25ns);
  localparam time c_I2C_PERIOD = time'(250ns);
  localparam int c_LOOPS = 10;
  localparam logic [6:0] c_ADDR = 7'h3B;

  typedef struct packed {
    logic       read;
    logic [7:0] data;
  } i2c_op_t;

  logic clk = 1'b0;
  logic reset = 1'b1;
  logic scl_o;
  logic sda_i;
  logic sda_o;
  logic sda_en_o;
  logic [7:0] cmd_data = '0;
  logic [6:0] cmd_address = c_ADDR;
  logic cmd_valid = 1'b0;
  logic cmd_error;
  logic cmd_ready;
  logic cmd_read = 1'b0;
  logic [7:0] rd_data;
  logic rd_valid;
  logic rd_ready;

  logic slv_sda_en = 1'b0;
  logic slv_sda_o = 1'b1;
  logic sda_line;
  logic scl_line;

  logic scl_r = 1'b1;
  logic sda_r = 1'b1;
  logic slv_arm = 1'b0;
  logic slv_done = 1'b0;
  int guard_n;

  typedef enum logic [2:0] {
    ST_IDLE  = 3'd0,
    ST_ADDR  = 3'd1,
    ST_ACKA  = 3'd2,
    ST_WR    = 3'd3,
    ST_ACKW  = 3'd4,
    ST_RD    = 3'd5,
    ST_RDACK = 3'd6,
    ST_WAIT  = 3'd7
  } slv_state_e;

  slv_state_e sst = ST_IDLE;
  logic arm_d = 1'b0;
  logic [7:0] shreg = '0;
  int bitn = 0;
  int oi_ff = 0;
  int nops_ff = 0;
  int idle_cnt = 0;
  logic nack_r = 1'b0;

  i2c_op_t exp_q[$];
  i2c_op_t cmd_q[$];
  logic [7:0] rd_q[$];
  string cur_name = "i2c";
  bit tb_done = 1'b0;

  always #(c_CLK_PERIOD / 2) clk = ~clk;

  // Wired-AND open-drain with a pull-up. Enable low releases the pin.
  assign sda_line = ((sda_en_o && !sda_o) || (slv_sda_en && !slv_sda_o)) ? 1'b0 : 1'b1;
  assign sda_i    = sda_line;
  assign scl_line = scl_o;
  assign rd_ready = 1'b1;

  i2c_controller #(
    .g_CLOCK_PERIOD(c_CLK_PERIOD),
    .g_I2C_PERIOD(c_I2C_PERIOD)
  ) dut (
    .clk_i(clk),
    .reset_i(reset),
    .scl_o(scl_o),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_en_o(sda_en_o),
    .cmd_data_i(cmd_data),
    .cmd_address_i(cmd_address),
    .cmd_valid_i(cmd_valid),
    .cmd_error_o(cmd_error),
    .cmd_ready_o(cmd_ready),
    .cmd_read_i(cmd_read),
    .rd_data_o(rd_data),
    .rd_valid_o(rd_valid),
    .rd_ready_i(rd_ready)
  );

  // Open-drain slave. Pin edges are detected in this process; a timing task
  // misses them under Verilator.
  always_ff @(posedge clk) begin
    logic rise;
    logic fall;
    logic start;
    logic stop;
    rise  = (scl_r == 1'b0) && (scl_line == 1'b1);
    fall  = (scl_r == 1'b1) && (scl_line == 1'b0);
    start = (scl_r == 1'b1) && (scl_line == 1'b1) &&
            (sda_r == 1'b1) && (sda_line == 1'b0);
    stop  = (scl_r == 1'b1) && (scl_line == 1'b1) &&
            (sda_r == 1'b0) && (sda_line == 1'b1);
    arm_d <= slv_arm;
    if (reset) begin
      sst        <= ST_IDLE;
      slv_done   <= 1'b0;
      slv_sda_en <= 1'b0;
      slv_sda_o  <= 1'b1;
      bitn       <= 0;
      oi_ff      <= 0;
      nops_ff    <= 0;
    end else if (slv_arm && !arm_d) begin
      sst        <= ST_IDLE;
      slv_done   <= 1'b0;
      slv_sda_en <= 1'b0;
      slv_sda_o  <= 1'b1;
      bitn       <= 0;
      oi_ff      <= 0;
      shreg      <= '0;
      idle_cnt   <= 0;
      nops_ff    <= exp_q.size();
    end else if (slv_arm && !slv_done) begin
      case (sst)
        ST_IDLE: begin
          slv_sda_en <= 1'b0;
          if (start) begin
            bitn  <= 0;
            shreg <= '0;
            sst   <= ST_ADDR;
          end
        end
        ST_ADDR, ST_WR: begin
          if (rise) begin
            shreg <= {shreg[6:0], sda_line};
            bitn  <= bitn + 1;
          end
          if (fall && (bitn == 8)) begin
            slv_sda_en <= 1'b1;
            slv_sda_o  <= 1'b0;
            sst        <= (sst == ST_ADDR) ? ST_ACKA : ST_ACKW;
          end
        end
        ST_ACKA: begin
          slv_sda_en <= 1'b1;
          slv_sda_o  <= 1'b0;
          if (fall) begin
            if (shreg[7:1] != c_ADDR)
              $fatal(1, "%s address 0x%02h", cur_name, shreg);
            if (oi_ff >= nops_ff)
              $fatal(1, "%s unexpected address", cur_name);
            if (shreg[0] != exp_q[oi_ff].read)
              $fatal(1, "%s rw got %0b exp %0b", cur_name, shreg[0], exp_q[oi_ff].read);
            bitn <= 0;
            shreg <= '0;
            if (shreg[0] == 1'b0) begin
              slv_sda_en <= 1'b0;
              slv_sda_o  <= 1'b1;
              sst        <= ST_WR;
            end else begin
              slv_sda_en <= 1'b1;
              slv_sda_o  <= exp_q[oi_ff].data[7];
              sst        <= ST_RD;
            end
          end
        end
        ST_ACKW: begin
          slv_sda_en <= 1'b1;
          slv_sda_o  <= 1'b0;
          if (fall) begin
            if (oi_ff >= nops_ff || exp_q[oi_ff].read)
              $fatal(1, "%s unexpected write 0x%02h", cur_name, shreg);
            if (shreg !== exp_q[oi_ff].data)
              $fatal(1, "%s write got 0x%02h exp 0x%02h", cur_name, shreg, exp_q[oi_ff].data);
            slv_sda_en <= 1'b0;
            slv_sda_o  <= 1'b1;
            oi_ff <= oi_ff + 1;
            bitn  <= 0;
            shreg <= '0;
            if ((oi_ff + 1) < nops_ff) begin
              if (!exp_q[oi_ff + 1].read)
                sst <= ST_WR;
              else begin
                idle_cnt <= 0;
                sst      <= ST_WAIT;
              end
            end else begin
              idle_cnt <= 0;
              sst      <= ST_WAIT;
            end
          end
        end
        ST_RD: begin
          if (rise)
            bitn <= bitn + 1;
          if (fall) begin
            if (bitn == 8) begin
              slv_sda_en <= 1'b0;
              slv_sda_o  <= 1'b1;
              sst        <= ST_RDACK;
            end else begin
              slv_sda_en <= 1'b1;
              slv_sda_o  <= exp_q[oi_ff].data[7 - bitn];
            end
          end
        end
        ST_RDACK: begin
          if (rise)
            nack_r <= sda_line;
          if (fall) begin
            oi_ff <= oi_ff + 1;
            if (nack_r || ((oi_ff + 1) >= nops_ff)) begin
              slv_sda_en <= 1'b0;
              slv_sda_o  <= 1'b1;
              idle_cnt   <= 0;
              sst        <= ST_WAIT;
            end else if (!exp_q[oi_ff + 1].read) begin
              slv_sda_en <= 1'b0;
              slv_sda_o  <= 1'b1;
              idle_cnt   <= 0;
              sst        <= ST_WAIT;
            end else begin
              bitn       <= 0;
              slv_sda_en <= 1'b1;
              slv_sda_o  <= exp_q[oi_ff + 1].data[7];
              sst        <= ST_RD;
            end
          end
        end
        ST_WAIT: begin
          slv_sda_en <= 1'b0;
          if (start) begin
            idle_cnt <= 0;
            bitn     <= 0;
            shreg    <= '0;
            sst      <= ST_ADDR;
          end else if (stop || (scl_line && sda_line && (idle_cnt == 16))) begin
            if (oi_ff != nops_ff)
              $fatal(1, "%s stop with %0d ops left", cur_name, nops_ff - oi_ff);
            slv_done <= 1'b1;
            sst      <= ST_IDLE;
          end else if (scl_line && sda_line) begin
            idle_cnt <= idle_cnt + 1;
          end else begin
            idle_cnt <= 0;
          end
        end
        default: sst <= ST_IDLE;
      endcase
    end else if (!slv_arm) begin
      slv_done <= 1'b0;
    end
    scl_r <= reset ? 1'b1 : scl_line;
    sda_r <= reset ? 1'b1 : sda_line;
  end

  always @(posedge clk) begin
    if (rd_valid)
      rd_q.push_back(rd_data);
  end

  always @(posedge clk) begin
    if (reset) begin
      cmd_valid <= 1'b0;
    end else if (cmd_valid && cmd_ready && (cmd_q.size() > 0)) begin
      void'(cmd_q.pop_front());
      if (cmd_q.size() > 0) begin
        cmd_data  <= cmd_q[0].data;
        cmd_read  <= cmd_q[0].read;
        cmd_valid <= 1'b1;
      end else begin
        cmd_valid <= 1'b0;
      end
    end else if (!cmd_valid && (cmd_q.size() > 0)) begin
      cmd_data  <= cmd_q[0].data;
      cmd_read  <= cmd_q[0].read;
      cmd_valid <= 1'b1;
    end
  end

  initial begin
    #20ms;
    if (!tb_done)
      $fatal(1, "i2c_controller_tb watchdog");
  end

  task automatic clk_step();
    @(posedge clk);
    guard_n++;
    if (guard_n > 40000) begin
      $display("I2C hang %s state=%0d scl=%b sda=%b en=%b oi=%0d done=%b",
               cur_name, sst, scl_line, sda_line, sda_en_o, oi_ff, slv_done);
      $fatal(1, "I2C timeout in %s", cur_name);
    end
  endtask

  task automatic slave_run();
    slv_arm = 1'b1;
    guard_n = 0;
    do clk_step(); while (slv_done);
    do clk_step(); while (!slv_done);
    slv_arm = 1'b0;
  endtask

  task automatic run_i2c();
    int exp_reads;
    int ri;
    rd_q  = {};
    cmd_q = {};
    // Queue the command before the slave waits. The controller needs the
    // divided I2C clock before it can start, so the slave is already watching.
    for (int i = 0; i < exp_q.size(); i++) begin
      i2c_op_t cmd;
      cmd.read = exp_q[i].read;
      cmd.data = exp_q[i].read ? 8'hAA : exp_q[i].data;
      cmd_q.push_back(cmd);
    end
    slave_run();
    repeat (20) @(posedge clk);
    if (cmd_error)
      $fatal(1, "%s cmd_error", cur_name);
    exp_reads = 0;
    for (int i = 0; i < exp_q.size(); i++) begin
      if (exp_q[i].read)
        exp_reads++;
    end
    if (rd_q.size() != exp_reads)
      $fatal(1, "%s read count got %0d exp %0d", cur_name, rd_q.size(), exp_reads);
    ri = 0;
    for (int i = 0; i < exp_q.size(); i++) begin
      if (exp_q[i].read) begin
        if (rd_q[ri] !== exp_q[i].data)
          $fatal(1, "%s read got 0x%02h exp 0x%02h", cur_name, rd_q[ri], exp_q[i].data);
        ri++;
      end
    end
  endtask

  task automatic push_op(input logic read, input logic [7:0] data);
    i2c_op_t op;
    op.read = read;
    op.data = data;
    exp_q.push_back(op);
  endtask

  initial begin
    reset      = 1'b1;
    cmd_valid  = 1'b0;
    cmd_address = c_ADDR;
    slv_sda_en = 1'b0;
    #(c_CLK_PERIOD);
    @(posedge clk);
    reset = 1'b0;
    repeat (4) @(posedge clk);

    $display("i2c_byte_write");
    cur_name = "i2c_byte_write";
    for (int i = 0; i < c_LOOPS; i++) begin
      exp_q = {};
      push_op(1'b0, 8'($urandom_range(255, 0)));
      run_i2c();
    end

    $display("i2c_multi_byte_read");
    cur_name = "i2c_multi_byte_read";
    for (int i = 0; i < c_LOOPS; i++) begin
      exp_q = {};
      push_op(1'b1, 8'($urandom_range(255, 0)));
      push_op(1'b1, 8'($urandom_range(255, 0)));
      run_i2c();
    end

    $display("i2c_write_then_read");
    cur_name = "i2c_write_then_read";
    for (int i = 0; i < c_LOOPS; i++) begin
      exp_q = {};
      push_op(1'b0, 8'($urandom_range(255, 0)));
      push_op(1'b1, 8'($urandom_range(255, 0)));
      run_i2c();
    end

    $display("i2c_read_then_write");
    cur_name = "i2c_read_then_write";
    for (int i = 0; i < c_LOOPS; i++) begin
      exp_q = {};
      push_op(1'b1, 8'($urandom_range(255, 0)));
      push_op(1'b0, 8'($urandom_range(255, 0)));
      run_i2c();
    end

    $display("i2c_multi_byte_write");
    cur_name = "i2c_multi_byte_write";
    for (int i = 0; i < c_LOOPS; i++) begin
      exp_q = {};
      push_op(1'b0, 8'($urandom_range(255, 0)));
      push_op(1'b0, 8'($urandom_range(255, 0)));
      push_op(1'b0, 8'($urandom_range(255, 0)));
      run_i2c();
    end

    tb_done = 1'b1;
    $display("PASS i2c_controller_tb");
    $finish;
  end
endmodule
