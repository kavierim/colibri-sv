// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
//
// Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

// Endec testbenches and bound SVA. Compile one testbench as --top.
// Pass the matching *_sva.sv on the command line for the RLE benches.
// 8b/10b benches have no PSL counterpart.

sim/endec/decode_8b10b_tb.sv
sim/endec/loopback_8b10b_tb.sv
sim/endec/rle_encode_tb.sv
sim/endec/rle_decode_tb.sv
fv/endec/rle_encode_sva.sv
fv/endec/rle_decode_sva.sv
