---
type: Module
title: packet_cc_ram_fifo
description: Dual-clock packet FIFO with RAM and mixed widths.
tags: [domain:memory, module:packet_cc_ram_fifo, cdc]
status: draft
resource: src/memory/packet_cc_ram_fifo.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Dual-clock packet FIFO with RAM and mixed widths.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_DATA_WIDTH       = 32` |
| `parameter int g_MAX_PACKET_BYTES = 256` |
| `parameter int g_NUM_PACKETS      = 4` |
| `parameter int g_SNK_DATA_WIDTH   = g_DATA_WIDTH` |
| `parameter int g_SRC_DATA_WIDTH   = g_DATA_WIDTH` |
| `parameter colibri_utils::compiler_t g_IMPL_STYLE = colibri_utils::get_compiler()` |


## Ports

| Declaration |
| --- |
| `input  logic reset_i` |
| `input  logic snk_clk_i` |
| `input  logic src_clk_i` |
| `input  logic snk_sop_i` |
| `input  logic snk_eop_i` |
| `input  logic [g_SNK_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_SNK_DATA_WIDTH / 8))-1:0] snk_empty_i` |
| `input  logic snk_valid_i` |
| `output logic snk_ready_o` |
| `input  logic snk_drop_i` |
| `output logic src_sop_o` |
| `output logic src_eop_o` |
| `output logic [g_SRC_DATA_WIDTH-1:0] src_data_o` |
| `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_SRC_DATA_WIDTH / 8))-1:0] src_empty_o` |
| `output logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_MAX_PACKET_BYTES * g_NUM_PACKETS))-1:0] src_size_o` |
| `input  logic src_ready_i` |
| `output logic src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Packet FIFO in a simple dual-port RAM, with a latency fifo and a size cc_fifo. g_MAX_PACKET_BYTES and g_NUM_PACKETS have elaboration defaults; the VHDL generics do not. Sink shaping uses skid_buffer and stream_buffer (src/common). Resets use synchro_reset (src/common). The read-side state names are SRC_IDLE and SRC_PACKET. SystemVerilog enum labels share the module scope, so they cannot repeat the write-side S_IDLE and S_PACKET. FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/packet_cc_ram_fifo.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `packet_cc_ram_fifo`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

packet_cc_ram_fifo #(
  // parameters from Schema
) u_packet_cc_ram_fifo (
  .reset_i (...),
  .snk_clk_i (...),
  .src_clk_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .snk_drop_i (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_size_o (...),
  .src_ready_i (...),
  // ...
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/packet_cc_ram_fifo/packet_cc_ram_fifo_tb.sv | none |

# Agent notes

- Read `src/memory/packet_cc_ram_fifo.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/packet_cc_ram_fifo/packet_cc_ram_fifo_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/packet_cc_ram_fifo.sv)
- [simulation](../../playbooks/simulation.md)
