<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Interface modules

Avalon-ST, AXI-Stream, and a small Wishbone RAM.

### Stream modules

In [`stream/`](stream/):

- `avst_cdc` — Avalon-ST clock-domain crossing.
- `avst_fifo` — Avalon-ST FIFO.
- `avst_to_axis` — Avalon-ST to AXI-Stream.
- `avst_width_converter` — Avalon-ST width converter.
- `axis_to_avst` — AXI-Stream to Avalon-ST.
- `avst_ram_write` — Avalon-ST writer into a RAM.
- `avst_ram_write_unaligned` — byte-addressable Avalon-ST writer.
- `avst_ram_read` — Avalon-ST reader from a RAM.
- `avst_ram_read_unaligned` — byte-addressable Avalon-ST reader.

In [`memory_mapped/`](memory_mapped/):

- `wb_ram` — RAM with a Wishbone B4 slave port.

Stream record types come from `colibri_types`.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `avst_cdc` | yes | `sim/interfaces/stream/avst_cdc_tb.sv` | no |
| `avst_fifo` | yes | `sim/interfaces/stream/avst_fifo_tb.sv` | no |
| `avst_to_axis` | yes | `sim/interfaces/stream/avst_to_axis_tb.sv` | `fv/interfaces/stream/avst_to_axis_sva.sv` |
| `avst_width_converter` | yes | `sim/interfaces/stream/avst_width_converter_tb.sv` | no |
| `axis_to_avst` | yes | `sim/interfaces/stream/axis_to_avst_tb.sv` | `fv/interfaces/stream/axis_to_avst_sva.sv` |
| `avst_ram_write` | yes | `sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv` | `fv/interfaces/stream/avst_ram_write_sva.sv` |
| `avst_ram_read` | yes | `sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv` | `fv/interfaces/stream/avst_ram_read_sva.sv` |
| `avst_ram_write_unaligned` | yes | `sim/interfaces/stream/avst_ram_write_unaligned_tb.sv`, `avst_ram_be_tb/` | `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` |
| `avst_ram_read_unaligned` | yes | `sim/interfaces/stream/avst_ram_read_unaligned_tb/`, `avst_ram_be_tb/` | no |
| `wb_ram` | yes | `sim/interfaces/memory_mapped/wb_ram_tb.sv` | no |
