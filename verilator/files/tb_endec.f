// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

// Endec testbenches and bound SVA. Compile one testbench as --top.
// Pass the matching *_sva.sv on the command line for the RLE benches.
// 8b/10b benches have no PSL counterpart.

sim/endec/decode_8b10b_tb.sv
sim/endec/loopback_8b10b_tb.sv
sim/endec/rle_encode_tb.sv
sim/endec/rle_decode_tb.sv
fv/endec/rle_encode_sva.sv
fv/endec/rle_decode_sva.sv
