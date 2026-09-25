<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Communication modules

Line coding, width conversion, and link checks.

### Modules

- `scrambler` — self-synchronous (multiplicative) scrambler.
- `descrambler` — self-synchronous descrambler.
- `slip_buffer` — slip buffer for stream alignment.
- `cc_gearbox` — dual-clock gearbox for any data width.
- `gearbox` — single-clock gearbox for any data width.
- `crc` — cyclic redundancy check on a packet stream.
- `bert` — PRBS bit-error-rate tester.
- `bit_shifter` — bit shift of a data stream.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `scrambler` | yes | `sim/comms/scrambler_tb.sv` | no |
| `descrambler` | yes | covered by `scrambler_tb` and `prbs_tb` | no |
| `slip_buffer` | yes | `sim/comms/slip_buffer_tb.sv` | no |
| `cc_gearbox` | yes | `sim/comms/cc_gearbox_up_tb.sv`, `cc_gearbox_down_tb.sv`, `cc_gearbox_*_thr_tb.sv`, `cc_gearbox_loopback_tb.sv` | no |
| `gearbox` | yes | `sim/comms/gearbox_up_tb.sv`, `gearbox_down_tb.sv`, `gearbox_loopback_tb.sv` | `fv/comms/gearbox_up_sva.sv`, `gearbox_down_sva.sv` (active only for the 4-to-12 and 12-to-4 widths) |
| `crc` | yes | `sim/comms/crc_tb.sv` | no |
| `bert` | yes | `sim/comms/bert_tb.sv` | no |
| `bit_shifter` | yes | `sim/comms/bit_shifter_tb.sv` | no |

### About gearboxes

Use `cc_gearbox` when the two sides have different clocks.

`cc_gearbox` reaches full throughput only when its internal FIFO is deep enough. Check that depth in simulation for the rate you need. It uses `cc_fifo` by default. `g_USE_BLOCK_RAM` selects the RAM FIFO. See [memory resource notes](../memory/readme.md#notes-on-resource-use).

### Use as PRBS

`scrambler` and `descrambler` can generate and check a PRBS:

- Pick a polynomial from `colibri_poly` ([`poly_pkg.sv`](../common/poly_pkg.sv)).
- Seed with a value that is not all zeros and not all ones.
- Drive a fixed signature word.
- Check that the received word matches the signature.

`sim/comms/prbs_tb.sv` is the example.
