<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-26, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Component catalog

This port contains **90 modules** and **12 packages** (102 RTL units). Module names match the upstream VHDL entities. VHDL packages use the `colibri_` prefix in SystemVerilog.

More detail per area: [`src/common/readme.md`](src/common/readme.md), [`src/memory/readme.md`](src/memory/readme.md), [`src/comms/readme.md`](src/comms/readme.md), [`src/endec/readme.md`](src/endec/readme.md), [`src/io/readme.md`](src/io/readme.md), [`src/interfaces/readme.md`](src/interfaces/readme.md), [`src/packet/readme.md`](src/packet/readme.md), [`src/pipes/readme.md`](src/pipes/readme.md), [`src/misc/readme.md`](src/misc/readme.md), [`src/proto/aurora_64b66b/readme.md`](src/proto/aurora_64b66b/readme.md), [`src/fileio/readme.md`](src/fileio/readme.md).

## Packages

| Name | Source | Description |
| --- | --- | --- |
| `colibri_utils` | `src/common/utils.sv` | Bit-math, registers, and byte manipulation. |
| `colibri_types` | `src/common/types.sv` | Avalon-ST and AXI-Stream types and conversion helpers. |
| `colibri_encoders` | `src/common/encoders.sv` | Gray, one-hot, and related encodings. |
| `colibri_poly` | `src/common/poly_pkg.sv` | CRC, scrambler, and PRBS polynomials. |
| `colibri_mem` | `src/memory/mem_pkg.sv` | Shared memory helpers. |
| `colibri_common_8b10b` | `src/endec/common_8b10b_pkg.sv` | 8b/10b encode and decode lookup tables. |
| `colibri_binaryio` | `src/fileio/binaryio.sv` | Simulation binary file read and write tasks. |
| `colibri_aurora_const` | `src/proto/aurora_64b66b/include/aurora_const_pkg.sv` | Aurora 64b/66b protocol constants. |
| `reg_utils` | `src/misc/mmap_fifo/vhdl_if/reg_utils.sv` | CSR field read/write helpers. |
| `mmap_fifo_csr_pkg` | `src/misc/mmap_fifo/vhdl_if/mmap_fifo_csr_pkg.sv` | Top-level mmap FIFO register definitions. |
| `txfifo_csr_pkg` | `src/misc/mmap_fifo/vhdl_if/txfifo_csr_pkg.sv` | TX FIFO CSR definitions. |
| `rxfifo_csr_pkg` | `src/misc/mmap_fifo/vhdl_if/rxfifo_csr_pkg.sv` | RX FIFO CSR definitions. |

## Common (`src/common/`)

| Module | Description |
| --- | --- |
| `counter` | Simple counter with optional modulo and enable. |
| `comparator` | Comparator with enable. |
| `debouncer` | Input debouncer. |
| `edge_detect` | Rising and falling edge detection. |
| `synchro` | Clock-domain crossing for a packed vector. |
| `synchro_generic` | CDC for a user-defined payload type. |
| `synchro_reset` | Reset synchronizer. |
| `synchro_pulse` | Pulse synchronizer across clock domains. |
| `synchro_handshake` | Stream CDC with backpressure propagation. |
| `stream_buffer` | Elastic stream buffer (skid or pipeline via generic). |
| `stream_buffer_generic` | Same buffer with a parameterized data type. |
| `skid_buffer` | Legacy low-latency elastic buffer; prefer `stream_buffer`. |
| `pipeline_buffer` | Legacy two-stage decoupled buffer; prefer `stream_buffer`. |

## Memory (`src/memory/`)

| Module | Description |
| --- | --- |
| `fifo` | Single-clock FIFO; arbitrary input and output width. |
| `cc_fifo` | Dual-clock asynchronous FIFO; arbitrary widths. |
| `cc_ram_fifo` | Dual-clock RAM-based FIFO with asymmetric ports. |
| `packet_fifo` | Single-clock Avalon-ST packet FIFO. |
| `packet_cc_fifo` | Dual-clock Avalon-ST packet FIFO (legacy style). |
| `packet_cc_ram_fifo` | Dual-clock packet FIFO with RAM and mixed widths. |
| `bicam` | Binary content-addressable memory. |
| `rom` | Read-only memory loaded from a hex init file. |
| `ram` | Single-port, single-clock RAM. |
| `simple_dpram` | Simple dual-port RAM (one write, one read); dual clock. |
| `simple_dpram_be` | `simple_dpram` with byte-enable on the write port. |
| `true_dpram` | True dual-port RAM (two write and two read ports). |
| `ring_buffer` | Circular buffer; overwrite oldest when full. |
| `simple_dpram_xilinx` | Vendor-style simple DPRAM for Xilinx BRAM inference. |
| `simple_dpram_altera` | Vendor-style simple DPRAM for Intel/Altera inference. |
| `true_dpram_xilinx` | Vendor-style true DPRAM for Xilinx. |
| `true_dpram_altera` | Vendor-style true DPRAM for Intel/Altera. |

## Communications (`src/comms/`)

| Module | Description |
| --- | --- |
| `scrambler` | Self-synchronous (multiplicative) scrambler. |
| `descrambler` | Matching descrambler. |
| `slip_buffer` | Slip buffer for stream bit alignment. |
| `gearbox` | Single-clock width gearbox. |
| `cc_gearbox` | Dual-clock width gearbox. |
| `crc` | CRC over an Avalon-ST packet stream. |
| `bert` | PRBS bit-error-rate tester. |
| `bit_shifter` | Arbitrary bit shift on a stream. |

## Encoders and decoders (`src/endec/`)

| Module | Description |
| --- | --- |
| `rle_encode` | Run-length encoder. |
| `rle_decode` | Run-length decoder. |
| `encode_8b10b` | 8b/10b encoder. |
| `decode_8b10b` | 8b/10b decoder. |

## I/O (`src/io/`)

| Module | Description |
| --- | --- |
| `uart` | UART transceiver (TX + RX). |
| `uart_tx` | UART transmitter only. |
| `uart_rx` | UART receiver only. |
| `spi_master` | SPI master. |
| `spi_slave` | SPI slave. |
| `i2c_controller` | I2C master controller. |
| `jtag_serdes` | JTAG USER-register duplex stream bridge. |

## Interfaces (`src/interfaces/`)

| Module | Description |
| --- | --- |
| `avst_cdc` | Avalon-ST clock-domain crossing. |
| `avst_fifo` | Avalon-ST FIFO wrapper. |
| `avst_to_axis` | Avalon-ST to AXI-Stream adapter. |
| `axis_to_avst` | AXI-Stream to Avalon-ST adapter. |
| `avst_width_converter` | Avalon-ST data-width converter. |
| `avst_ram_write` | Write Avalon-ST beats into RAM. |
| `avst_ram_write_unaligned` | Byte-addressable Avalon-ST RAM writer. |
| `avst_ram_read` | Read Avalon-ST beats from RAM. |
| `avst_ram_read_unaligned` | Byte-addressable Avalon-ST RAM reader. |
| `wb_ram` | RAM with Wishbone B4 slave port. |

## Packet streams (`src/packet/`)

| Module | Description |
| --- | --- |
| `header_add` | Prepend a fixed header to each packet. |
| `header_remove` | Strip a fixed header from each packet. |
| `interleaver` | Merge multiple packet streams into one. |
| `deinterleaver` | Split one stream into multiple outputs. |
| `broadcaster` | Duplicate one stream to several outputs. |
| `packet_join` | Concatenate consecutive packets into one. |
| `packet_delay` | Delay packets by a fixed number of clocks. |

## Pipes (`src/pipes/`)

| Module | Description |
| --- | --- |
| `arbiter` | Round-robin arbiter for multiple stream sources. |

## Miscellaneous (`src/misc/`)

| Module | Description |
| --- | --- |
| `be_add_lead` | Insert a leading word on an Avalon-ST packet. |
| `be_add_trail` | Append a trailing word (e.g. CRC). |
| `be_remove_lead` | Remove the leading word (e.g. header). |
| `be_remove_trail` | Remove the trailing word (e.g. CRC). |
| `mmap_fifo` | Wishbone slave to full-duplex Avalon-ST packet FIFO. |
| `mmap_fifo_tx` | TX half of `mmap_fifo`. |
| `mmap_fifo_rx` | RX half of `mmap_fifo`. |
| `mmap_fifo_csr` | Top CSR block for mmap FIFO. |
| `txfifo_csr` | TX FIFO CSR block. |
| `rxfifo_csr` | RX FIFO CSR block. |
| `heartbeat` | Periodic heartbeat from a divided counter. |
| `powerup_reset` | Power-up reset stretcher. |
| `stream_to_wbm` | Bidirectional stream to Wishbone B4 master. |
| `frequency_counter` | Measure an input clock against a reference. |

## Aurora 64b/66b (`src/proto/aurora_64b66b/`)

| Module | Description |
| --- | --- |
| `aurora_tx` | Aurora transmitter (64b stream to encoded lanes). |
| `aurora_rx` | Aurora receiver (lanes to 64b stream). |
| `aurora_st_encoder` | Aurora stream encoder block. |
| `aurora_st_decoder` | Aurora stream decoder block. |
| `gearbox_up` | Continuous upscaling gearbox (RX path). |
| `cc_gearbox_up` | Clock-crossing upscaling gearbox variant. |
| `block_sync_fsm` | Block synchronization state machine. |
| `channel_bond` | Multi-lane channel bonding. |
| `meta_buffer` | Metadata buffer in the RX datapath. |
