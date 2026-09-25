<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Encoding and decoding modules

Run-length coding and 8b/10b. The 8b/10b symbol tables are package `colibri_common_8b10b` (`common_8b10b_pkg.sv`), the VHDL package `common_8b10b`.

### Modules

- `rle_encode` — run-length encoder.
- `rle_decode` — run-length decoder.
- `encode_8b10b` — 8b/10b encoder.
- `decode_8b10b` — 8b/10b decoder.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `rle_encode` | yes | `sim/endec/rle_encode_tb.sv` | `fv/endec/rle_encode_sva.sv` |
| `rle_decode` | yes | `sim/endec/rle_decode_tb.sv` | `fv/endec/rle_decode_sva.sv` |
| `encode_8b10b` | yes | `sim/endec/loopback_8b10b_tb.sv` | no |
| `decode_8b10b` | yes | `sim/endec/decode_8b10b_tb.sv`, `loopback_8b10b_tb.sv` | no |
