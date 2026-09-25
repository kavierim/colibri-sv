<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Packet modules

Operations on packet streams (Avalon-ST style: start, end, and data).

### Modules

- [`header_remove.sv`](header_remove.sv) — drop a fixed-size header.
- [`header_add.sv`](header_add.sv) — insert a fixed-size header.
- [`interleaver.sv`](interleaver.sv) — many streams into one.
- [`deinterleaver.sv`](deinterleaver.sv) — one stream into many.
- [`broadcaster.sv`](broadcaster.sv) — one stream copied to many.
- [`packet_join.sv`](packet_join.sv) — join consecutive packets into one.
- [`packet_delay.sv`](packet_delay.sv) — delay packets by a set number of clocks.

Shared testbench helpers are `sim/packet/packet_tb_pkg.sv`.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `header_remove` | yes | `sim/packet/header_remove_tb.sv` | `fv/packet/header_remove_sva.sv` |
| `header_add` | yes | `sim/packet/header_add_tb.sv` | `fv/packet/header_add_sva.sv` |
| `interleaver` | yes | `sim/packet/interleaver_tb.sv` | `fv/packet/interleaver_sva.sv`, `interleaver_bd_sva.sv` |
| `deinterleaver` | yes | `sim/packet/interleaver_loopback_tb.sv` | `fv/packet/deinterleaver_sva.sv` |
| `broadcaster` | yes | `sim/packet/broadcaster_tb.sv` | `fv/packet/broadcaster_sva.sv` |
| `packet_join` | yes | `sim/packet/packet_join_tb.sv` | `fv/packet/packet_join_sva.sv` |
| `packet_delay` | yes | `sim/packet/packet_delay_tb.sv` | `fv/packet/packet_delay_sva.sv` |
