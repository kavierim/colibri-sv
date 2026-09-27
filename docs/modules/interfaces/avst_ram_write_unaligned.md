---
type: Module
title: avst_ram_write_unaligned
description: Byte-addressable Avalon-ST RAM writer.
tags: [domain:interfaces, module:avst_ram_write_unaligned, interface:avst]
status: draft
resource: src/interfaces/stream/avst_ram_write_unaligned.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Interfaces_Stream::avst_ram_write_unaligned
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
---
# Purpose

Byte-addressable Avalon-ST RAM writer.

# When to use

See the [interfaces domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_BYTE_WIDTH = 8` |
| `parameter int unsigned g_WORD_BYTES = 8` |
| `parameter int unsigned g_RAM_DEPTH  = 16` |

## Ports

| Declaration |
| --- |
| `input  logic                       clk_i` |
| `input  logic                       reset_i` |
| `input  logic [c_DATA_W-1:0]        snk_data_i` |
| `input  logic [c_EMPTY_W-1:0]       snk_empty_i` |
| `input  logic                       snk_sop_i` |
| `input  logic                       snk_eop_i` |
| `input  logic                       snk_valid_i` |
| `output logic                       snk_ready_o` |
| `input  logic [c_BYTE_ADDR_W-1:0]   start_addr_i` |
| `input  logic                       flush_i` |
| `output logic [g_WORD_BYTES-1:0]    wr_be_o` |
| `output logic [c_ADDR_W-1:0]        wr_addr_o` |
| `output logic [c_DATA_W-1:0]        wr_data_o` |

Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.

# Behaviour

Avalon Stream to RAM writer with unaligned (byte-addressable) access. Writes Avalon-ST packets to a word-addressed RAM with a byte-enable vector. start_addr_i is the initial byte address at start of packet. An extra write after end of packet can deassert snk_ready_o for one cycle. RAM outputs are delayed by 2 cycles. flush_i writes any bytes still in the buffer. Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Requirements

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-001"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-001

The cycle after reset_i, wr_be_o shall be zero and the FSM shall be in S_IDLE.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_reset_idle`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-002"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-002

In S_IDLE without a accepted SOP beat, the FSM shall remain in S_IDLE on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_idle_hold`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-003"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-003

An accepted SOP beat in S_IDLE shall move the FSM to S_SOP on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_idle_to_sop`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-004"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-004

In S_SOP without the SOP completion condition, the FSM shall not leave S_SOP on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_sop_stay`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-005"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-005

After a qualifying EOP in S_SOP, a new SOP handshake shall keep S_SOP.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_sop_chain`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-006"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-006

After a qualifying EOP in S_SOP without a new SOP, the FSM shall return to S_IDLE.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_sop_to_idle`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-007"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-007

A non-EOP beat after S_SOP shall enter S_WRITE on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_sop_to_write`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-008"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-008

A short final word in S_SOP shall move to S_EOP on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_sop_to_eop_short`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-009"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-009

An EOP beat in S_SOP shall move to S_EOP on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_sop_eop_to_eop`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-010"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-010

In S_WRITE without EOP or flush, the FSM shall stay in S_WRITE.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_write_hold`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-011"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-011

An EOP or flush in S_WRITE shall move to S_EOP on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_write_to_eop`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-012"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-012

In S_EOP while snk_ready_o is low, the FSM shall remain in S_EOP.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_eop_stall`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-013"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-013

In S_EOP with snk_ready_o and no new SOP, the FSM shall return to S_IDLE.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_eop_to_idle`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-014"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-014

In S_EOP with snk_ready_o and a new SOP, the FSM shall enter S_SOP.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_eop_to_sop`

<a id="REQ-AVST_RAM_WRITE_UNALIGNED-015"></a>

## REQ-AVST_RAM_WRITE_UNALIGNED-015

Flush in S_SOP or S_WRITE shall move the FSM to S_IDLE or S_EOP.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_write_unaligned_sva.sv` property `t_flush_escape`

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_ram_write_unaligned.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `avst_ram_write_unaligned`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_ram_write_unaligned #(
  // parameters from Schema
) u_avst_ram_write_unaligned (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_empty_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .start_addr_i (...),
  .flush_i (...),
  .wr_be_o (...),
  .wr_addr_o (...),
  .wr_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_ram_write_unaligned_tb.sv, avst_ram_be_tb/ | fv/interfaces/stream/avst_ram_write_unaligned_sva.sv |

# Agent notes

- Read `src/interfaces/stream/avst_ram_write_unaligned.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_ram_write_unaligned_tb.sv, avst_ram_be_tb/` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_ram_write_unaligned.sv)
- [simulation](../../playbooks/simulation.md)
