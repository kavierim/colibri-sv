---
type: Module
title: avst_ram_read
description: Read Avalon-ST beats from RAM.
tags: [domain:interfaces, module:avst_ram_read, interface:avst]
status: draft
resource: src/interfaces/stream/avst_ram_read.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Interfaces_Stream::avst_ram_read
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
---
# Purpose

Read Avalon-ST beats from RAM.

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
| `input  logic                     clk_i` |
| `input  logic                     reset_i` |
| `output logic [c_DATA_W-1:0]      src_data_o` |
| `output logic [c_EMPTY_W-1:0]     src_empty_o` |
| `output logic                     src_sop_o` |
| `output logic                     src_eop_o` |
| `output logic                     src_valid_o` |
| `input  logic                     src_ready_i` |
| `input  logic [c_ADDR_W-1:0]      start_addr_i` |
| `input  logic [c_LEN_W-1:0]       length_i` |
| `input  logic                     start_i` |
| `input  logic                     stop_i` |
| `output logic                     busy_o` |
| `output logic                     rd_en_o` |
| `output logic [c_ADDR_W-1:0]      rd_addr_o` |
| `input  logic [c_DATA_W-1:0]      rd_data_i` |

Key types and width rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md) and [`colibri_types`](../../packages/colibri_types.md) when stream records are used.

# Behaviour

Simple Avalon Stream to RAM reader. Sequential reads through a RAM interface, presented as a packeted Avalon-ST output. length_i is a byte count. A length of 0 reads until stop_i. start_i is accepted only while busy_o is low. stop_i ends the transfer. Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](../../playbooks/stream-interfaces.md).

# Requirements

<a id="REQ-AVST_RAM_READ-001"></a>

## REQ-AVST_RAM_READ-001

The cycle after reset_i, busy_o, src_valid_o, and rd_en_o shall be low.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_reset_idle`

<a id="REQ-AVST_RAM_READ-002"></a>

## REQ-AVST_RAM_READ-002

After rd_start without backpressure, the next cycle shall enable a read and assert busy_o when needed.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_rd_start`

<a id="REQ-AVST_RAM_READ-003"></a>

## REQ-AVST_RAM_READ-003

After a read enable without backpressure, the next cycle shall present rd_data_i on src_data_o with src_valid_o.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_data_forward`

<a id="REQ-AVST_RAM_READ-004"></a>

## REQ-AVST_RAM_READ-004

Non-zero src_empty_o shall only occur with src_eop_o.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_empty_eop`

<a id="REQ-AVST_RAM_READ-005"></a>

## REQ-AVST_RAM_READ-005

src_sop_o or src_eop_o shall imply src_valid_o.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_sop_eop_valid`

<a id="REQ-AVST_RAM_READ-006"></a>

## REQ-AVST_RAM_READ-006

Under backpressure on a non-SOP beat, AVST outputs shall remain stable.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_backpressure_stable`

<a id="REQ-AVST_RAM_READ-007"></a>

## REQ-AVST_RAM_READ-007

On the last word of a capped read, busy_o shall be low when rd_en_o is high.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_busy_last_word`

<a id="REQ-AVST_RAM_READ-008"></a>

## REQ-AVST_RAM_READ-008

After stop_i, busy_o shall be low on the next cycle.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_stop_clears_busy`

<a id="REQ-AVST_RAM_READ-009"></a>

## REQ-AVST_RAM_READ-009

Successive rd_en_o cycles shall use incrementing rd_addr_o while busy.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_addr_increment`

<a id="REQ-AVST_RAM_READ-010"></a>

## REQ-AVST_RAM_READ-010

After rd_start with pending output, the first src_valid_o shall carry src_sop_o.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_first_sop`

<a id="REQ-AVST_RAM_READ-011"></a>

## REQ-AVST_RAM_READ-011

Before the captured length is emitted, the final beat shall assert src_eop_o.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_last_eop`

<a id="REQ-AVST_RAM_READ-012"></a>

## REQ-AVST_RAM_READ-012

On the final beat, src_empty_o shall match the encoded partial word.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_last_empty`

<a id="REQ-AVST_RAM_READ-013"></a>

## REQ-AVST_RAM_READ-013

After stop_i with in-flight data, the next handshake shall be an end-of-packet.

- Kind: extracted
- Verified by: `fv/interfaces/stream/avst_ram_read_sva.sv` property `t_stop_eop`

# Integration

- Verilator: add `verilator/files/interfaces.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/interfaces/stream/avst_ram_read.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `avst_ram_read`.

# Examples

```systemverilog
// Compile verilator/files/interfaces.f and verilator/colibri.f

avst_ram_read #(
  // parameters from Schema
) u_avst_ram_read (
  .clk_i (...),
  .reset_i (...),
  .src_data_o (...),
  .src_empty_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .start_addr_i (...),
  .length_i (...),
  .start_i (...),
  .stop_i (...),
  .busy_o (...),
  .rd_en_o (...),
  .rd_addr_o (...),
  .rd_data_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv | fv/interfaces/stream/avst_ram_read_sva.sv |

# Agent notes

- Read `src/interfaces/stream/avst_ram_read.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [interfaces RTL](../../../src/interfaces/stream/avst_ram_read.sv)
- [simulation](../../playbooks/simulation.md)
