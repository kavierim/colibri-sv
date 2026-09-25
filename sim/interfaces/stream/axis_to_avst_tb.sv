// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

`timescale 1ns/1ps

// AXI-Stream to Avalon-ST. Same packets as axis_to_avst_tb: 21 slices of a
// 30-byte ramp, for BIG and LITTLE Avalon byte order.
module axis_to_avst_harness #(
  parameter colibri_types::endian_t g_AVST_ENDIANNESS = colibri_types::BIG,
  parameter int c_DATA_W = 32,
  localparam int c_KEEP_W  = colibri_utils::downto_width(c_DATA_W / 8),
  localparam int c_EMPTY_W = colibri_utils::downto_width(colibri_utils::log2ceil(c_DATA_W / 8)),
  localparam int c_BYTES   = c_DATA_W / 8,
  localparam int c_N_PACKETS = 20,
  localparam int c_MSG_LEN   = 10 + c_N_PACKETS
) (
  output logic done
);

  logic                    clk = 1'b0;
  logic                    reset = 1'b1;
  logic                    snk_tready;
  logic                    snk_tvalid = 1'b0;
  logic                    snk_tlast = 1'b0;
  logic [c_KEEP_W-1:0]     snk_tkeep = {c_KEEP_W{1'b1}};
  logic [c_DATA_W-1:0]     snk_tdata = '0;
  logic                    src_ready = 1'b1;
  logic                    src_valid;
  logic                    src_sop;
  logic                    src_eop;
  logic [c_EMPTY_W-1:0]    src_empty;
  logic [c_DATA_W-1:0]     src_data;

  logic [7:0] exp_bytes [$];
  int         exp_len [$];
  int         got_i;
  int         pkt_got;
  bit         saw_sop;
  int         pkt_left;

  always #5 clk = ~clk;

  axis_to_avst #(
    .g_DATA_WIDTH      (c_DATA_W),
    .g_AVST_ENDIANNESS (g_AVST_ENDIANNESS)
  ) dut (
    .clk_i        (clk),
    .reset_i      (reset),
    .snk_tready_o (snk_tready),
    .snk_tvalid_i (snk_tvalid),
    .snk_tlast_i  (snk_tlast),
    .snk_tkeep_i  (snk_tkeep),
    .snk_tdata_i  (snk_tdata),
    .src_ready_i  (src_ready),
    .src_valid_o  (src_valid),
    .src_sop_o    (src_sop),
    .src_eop_o    (src_eop),
    .src_empty_o  (src_empty),
    .src_data_o   (src_data)
  );

  function automatic logic [c_DATA_W-1:0] pack_axis(input int base, input int n);
    logic [c_DATA_W-1:0] w;
    w = '0;
    for (int i = 0; i < n; i++)
      w[i*8 +: 8] = exp_bytes[base+i];
    return w;
  endfunction

  function automatic logic [7:0] avst_byte(input int lane);
    if (g_AVST_ENDIANNESS == colibri_types::BIG)
      return src_data[c_DATA_W-1 - lane*8 -: 8];
    else
      return src_data[lane*8 +: 8];
  endfunction

  always @(posedge clk) begin : proc_check
    int n;
    if (!reset && src_valid && src_ready) begin
      n = c_BYTES - int'(src_empty);
      if ((n < 1) || (n > c_BYTES))
        $fatal(1, "axis_to_avst empty %0d", src_empty);
      if (!src_eop && (src_empty != '0))
        $fatal(1, "axis_to_avst empty set before end of packet");
      if (!saw_sop) begin
        if (!src_sop)
          $fatal(1, "axis_to_avst missing start of packet");
        saw_sop = 1'b1;
      end else if (src_sop) begin
        $fatal(1, "axis_to_avst repeated start of packet");
      end
      for (int i = 0; i < n; i++) begin
        if (got_i >= exp_bytes.size())
          $fatal(1, "axis_to_avst extra byte");
        if (avst_byte(i) !== exp_bytes[got_i])
          $fatal(1, "axis_to_avst data mismatch at %0d: got %02h exp %02h",
                 got_i, avst_byte(i), exp_bytes[got_i]);
        got_i++;
        pkt_got++;
      end
      if (src_eop) begin
        if (exp_len.size() == 0)
          $fatal(1, "axis_to_avst unexpected end of packet");
        if (pkt_got != exp_len[0])
          $fatal(1, "axis_to_avst length got %0d exp %0d", pkt_got, exp_len[0]);
        exp_len.pop_front();
        pkt_got = 0;
        saw_sop = 1'b0;
        pkt_left--;
      end
    end
  end

  initial begin : proc_seq
    int len;
    int base;
    int n;
    int guard;
    done    = 1'b0;
    got_i   = 0;
    pkt_got = 0;
    saw_sop = 1'b0;
    base    = 0;
    for (int i = 0; i <= c_N_PACKETS; i++) begin
      len = c_MSG_LEN - i;
      exp_len.push_back(len);
      for (int k = 0; k < len; k++)
        exp_bytes.push_back(8'(c_MSG_LEN - 1 - k));
    end
    pkt_left = exp_len.size();

    @(posedge clk);
    #1;
    reset = 1'b0;
    repeat (4) @(posedge clk);

    for (int i = 0; i <= c_N_PACKETS; i++) begin
      len = c_MSG_LEN - i;
      while (len > 0) begin
        n = (len > c_BYTES) ? c_BYTES : len;
        #1;
        snk_tvalid = 1'b1;
        snk_tlast  = (n == len);
        snk_tkeep  = (n == c_BYTES) ? {c_KEEP_W{1'b1}} : (c_KEEP_W'(1) << n) - 1;
        snk_tdata  = pack_axis(base, n);
        @(posedge clk);
        guard = 0;
        while (!snk_tready) begin
          @(posedge clk);
          #1;
          guard++;
          if (guard > 1000)
            $fatal(1, "axis_to_avst ready timeout");
        end
        base += n;
        len  -= n;
      end
      #1;
      snk_tvalid = 1'b0;
      snk_tlast  = 1'b0;
      snk_tkeep  = {c_KEEP_W{1'b1}};
    end

    guard = 0;
    while (pkt_left != 0) begin
      @(posedge clk);
      #1;
      guard++;
      if (guard > 10000)
        $fatal(1, "axis_to_avst output timeout");
    end
    repeat (4) @(posedge clk);
    done = 1'b1;
  end

endmodule

module axis_to_avst_tb;
  logic [1:0] done;

  axis_to_avst_harness #(.g_AVST_ENDIANNESS(colibri_types::BIG)) u_big (.done(done[0]));
  axis_to_avst_harness #(.g_AVST_ENDIANNESS(colibri_types::LITTLE)) u_little (.done(done[1]));

  initial begin
    wait (&done);
    $display("axis_to_avst_tb PASS");
    $finish;
  end

  initial begin
    #1ms;
    $fatal(1, "axis_to_avst_tb watchdog");
  end
endmodule
