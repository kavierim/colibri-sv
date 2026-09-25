<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Memory modules

Memories and FIFOs. Shared helpers are in package `colibri_mem` (`mem_pkg.sv`), the VHDL package `mem`.

### Modules

- `fifo` — single-clock synchronous FIFO, any input width to any output width.
- `cc_fifo` — dual-clock asynchronous FIFO, any input width to any output width.
- `cc_ram_fifo` — dual-clock RAM FIFO with asymmetric ports. See [Optimized versions](#optimized-versions).
- `packet_fifo` — single-clock Avalon-ST packet FIFO.
- `packet_cc_fifo` — dual-clock Avalon-ST packet FIFO (legacy).
- `packet_cc_ram_fifo` — dual-clock Avalon-ST packet FIFO with mixed data widths and write-side packet drop. Built from RAM primitives. See [Optimized versions](#optimized-versions).
- `bicam` — binary content-addressable memory.
- `rom` — read-only memory.
- `ram` — single-port, single-clock RAM.
- `simple_dpram` — one write port, one read port, dual-clock RAM, asymmetric ports supported. See [Optimized versions](#optimized-versions).
- `simple_dpram_be` — the same shape with a byte-enable on the write port.
- `true_dpram` — two write ports, two read ports, dual-clock RAM, asymmetric ports supported. See [Optimized versions](#optimized-versions).
- `ring_buffer` — circular buffer. A write when full drops the oldest element.

### Usage notes

Every FIFO can run in first-word fall-through mode (`g_ENABLE_FWFT`), also called lookahead on Altera primitives. In that mode `rdreq` is an acknowledge and `empty` means not-valid.

With `g_ENABLE_FWFT` clear, `rdreq` is a read request and the output is valid after the request is accepted.

Packet RAM FIFOs calculate the packet size by default. The size is the synchronisation word between the write side and the read side. Packet FIFOs expose that calculation through `g_ENABLE_SIZE_COUNT`.

## Optimized versions

Vendor-oriented variants are in [`optimized/`](optimized/). They follow the coding style of the vendor named in the file (`simple_dpram_xilinx.sv`, `simple_dpram_altera.sv`, and the `true_dpram_*` pair) so synthesis maps them onto RAM primitives. The default implementation is chosen by `get_compiler()`. `g_IMPL_STYLE` forces a specific one.

These variants stay vendor-agnostic in simulation: they do not need a vendor simulator licence. Synthesising one vendor's style with another vendor's tool is possible; the styles exist so each tool recognises its primitive.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `fifo` | yes | `sim/memory/fifo_tb.sv`, `fifo_fwft_tb.sv`, `mixedw_fifo_tb.sv`, `mixedw_fifo_fwft_tb.sv` | `fv/memory/fifo_sva.sv` (bound on `fifo_tb`) |
| `cc_fifo` | yes | `sim/memory/cc_fifo_tb.sv`, `mixedw_cc_fifo_tb.sv`, `mixedw_cc_fifo_fwft_tb.sv` | no |
| `cc_ram_fifo` | yes | `sim/memory/cc_ram_fifo_tb.sv` | no |
| `packet_fifo` | yes | `sim/memory/packet_fifo/packet_fifo_tb.sv` | no |
| `packet_cc_fifo` | yes | `sim/memory/packet_cc_fifo/packet_cc_fifo_tb.sv` | no |
| `packet_cc_ram_fifo` | yes | `sim/memory/packet_cc_ram_fifo/packet_cc_ram_fifo_tb.sv` | no |
| `bicam` | yes | `sim/memory/bicam_tb.sv` | no |
| `rom` | yes | `sim/memory/rom/rom_tb.sv` | no |
| `ram` | yes | `sim/memory/ram_tb.sv` | no |
| `simple_dpram` | yes | `sim/memory/simple_dpram_tb.sv` | no |
| `simple_dpram_be` | yes | `sim/memory/simple_dpram_be_tb.sv` | no |
| `true_dpram` | yes | `sim/memory/true_dpram_tb.sv` | no |
| `ring_buffer` | yes | `sim/memory/ring_buffer_tb.sv` | `fv/memory/ring_buffer_sva.sv` |

### Notes on resource use

`cc_ram_fifo` uses fewer logic resources than `cc_fifo` when the widths differ, because the RAM ports absorb the width change instead of a logic gearbox. The RAM inference still depends on the coding style above.

An example scan in Xilinx Vivado 2024.1, carried over from the upstream VHDL notes:

| Module | INPUT_WIDTH | OUTPUT_WIDTH | LUTs | FFs | BRAMs | DSPs |
| --- | --- | --- | --- | --- | --- | --- |
| `cc_fifo` | 4 | 32 | 285 | 198 | 0 | 0 |
| `cc_ram_fifo` | 4 | 32 | 40 | 48 | 0.5 | 0 |
| `cc_fifo` | 8 | 32 | 240 | 201 | 0 | 0 |
| `cc_ram_fifo` | 8 | 32 | 39 | 44 | 0.5 | 0 |
| `cc_fifo` | 32 | 32 | 68 | 68 | 0 | 0 |
| `cc_ram_fifo` | 32 | 32 | 68 | 68 | 0 | 0 |
