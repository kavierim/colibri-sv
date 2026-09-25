<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Protocol modules

Higher-level link protocols.

### Modules

- [`aurora_64b66b`](aurora_64b66b/readme.md) — Aurora 64b/66b transmitter and receiver.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `aurora_64b66b` | yes | `sim/proto/aurora_64b66b/` | no |
