<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Miscellaneous modules

Blocks that do not belong in the other directories.

### Modules

- `be_add_lead` — insert a leading word on an Avalon-ST packet and shift the rest forward.
- `be_add_trail` — append a trailing word and update `empty`. Used to attach a CRC.
- `be_remove_lead` — remove the leading word and update `empty`. Used to strip a header.
- `be_remove_trail` — remove the trailing word and update `empty`. Used to strip a CRC.
- `mmap_fifo` — Wishbone to full-duplex Avalon-ST packet FIFO. `mmap_fifo_tx` and `mmap_fifo_rx` are the one-direction variants. Register blocks are the SystemVerilog translation of the upstream generated VHDL, in [`mmap_fifo/vhdl_if/`](mmap_fifo/vhdl_if/). The FIFOs are `cc_fifo` unless `g_USE_BLOCK_RAM` selects a RAM FIFO. See [memory resource notes](../memory/readme.md#notes-on-resource-use). The RX test keeps simple packets to 56 bytes because the RX FSM reports overflow at `NUM_WORDS-2` words.
- `heartbeat` — divided-down heartbeat from a counter.
- `powerup_reset` — power-up reset stretch.
- `stream_to_wbm` — bidirectional stream to a Wishbone B4 master. Used to reach registers over UART.
- `frequency_counter` — measure an arbitrary clock against a known reference.

### Development status and testing

| Module | Simulation | Self-checking testbench | SVA |
| --- | --- | --- | --- |
| `be_add_lead` | yes | `sim/misc/be_add_lead_tb.sv` | `fv/misc/be_add_lead_sva.sv` |
| `be_add_trail` | yes | `sim/misc/be_add_trail_tb.sv` | `fv/misc/be_add_trail_sva.sv` |
| `be_remove_lead` | yes | `sim/misc/be_remove_lead_tb.sv` | `fv/misc/be_remove_lead_sva.sv` |
| `be_remove_trail` | yes | `sim/misc/be_remove_trail_tb.sv` | `fv/misc/be_remove_trail_sva.sv` |
| `mmap_fifo_tx` | yes | `sim/misc/mmap_fifo/mmap_fifo_tb.sv` | no |
| `mmap_fifo_rx` | yes | `sim/misc/mmap_fifo/mmap_fifo_tb.sv` | no |
| `mmap_fifo` | yes | `sim/misc/mmap_fifo/mmap_fifo_tb.sv` | no |
| `heartbeat` | yes | `sim/misc/heartbeat_tb.sv` | no |
| `powerup_reset` | yes | `sim/misc/powerup_reset_tb.sv` | no |
| `stream_to_wbm` | yes | `sim/misc/stream_to_wbm_tb.sv` | no |
| `frequency_counter` | yes | `sim/misc/frequency_counter_tb.sv` | no |

### Register maps

The files under `mmap_fifo/vhdl_if/` are the translation of the upstream PeakRDL VHDL export (`mmap_fifo_csr`, `txfifo_csr`, `rxfifo_csr`, and `reg_utils`). Regenerating those maps is an upstream VHDL step (`peakrdl regblock-vhdl` on the `.rdl` sources). This port does not run PeakRDL.
