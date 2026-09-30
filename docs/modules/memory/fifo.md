---
type: Module
title: fifo
description: Single-clock FIFO; arbitrary input and output width.
tags: [domain:memory, module:fifo]
status: stable
resource: src/memory/fifo.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
model: sysml://Colibri::Memory::fifo
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
---
# Purpose

Single-clock FIFO; arbitrary input and output width.

# When to use

See the [memory domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_NUM_WORDS    = 4` |
| `parameter int g_INPUT_WIDTH  = 8` |
| `parameter int g_OUTPUT_WIDTH = g_INPUT_WIDTH` |
| `parameter bit g_ENABLE_FWFT  = 1'b0` |

## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic [g_INPUT_WIDTH-1:0] data_i` |
| `input  logic wrreq_i` |
| `input  logic rdreq_i` |
| `output logic [g_OUTPUT_WIDTH-1:0] q_o` |
| `output logic [colibri_utils::log2ceil(g_NUM_WORDS):0] usedw_o` |
| `output logic empty_o` |
| `output logic full_o` |

Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).

# Behaviour

Single-clock FIFO. The shared-variable memory is a logic array updated in always_ff. Mixed input/output widths instantiate gearbox (src/comms). Optional first-word fall-through: with `g_ENABLE_FWFT` set, `rdreq` acts as acknowledge and `empty` means not-valid; otherwise `rdreq` is a read request with one-cycle data latency.

# Model

Behavioral Python class: colibri_model.fifo.fifo (model/colibri_model/fifo.py).

# Requirements

<a id="REQ-FIFO-001"></a>

## REQ-FIFO-001

The cycle after reset_i, empty_o shall be high.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_after_reset_empty`

<a id="REQ-FIFO-002"></a>

## REQ-FIFO-002

The cycle after reset_i, full_o shall be low.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_after_reset_n_full`

<a id="REQ-FIFO-003"></a>

## REQ-FIFO-003

The cycle after reset_i, usedw_o shall be zero.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_after_reset_usedw`

<a id="REQ-FIFO-004"></a>

## REQ-FIFO-004

When usedw_o is zero, empty_o shall be high.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_usedw_empty`

<a id="REQ-FIFO-005"></a>

## REQ-FIFO-005

When usedw_o equals g_NUM_WORDS, full_o shall be high.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_usedw_full`

<a id="REQ-FIFO-006"></a>

## REQ-FIFO-006

A write without read while not full shall increment usedw_o by one on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_wr_no_rd_normal`

<a id="REQ-FIFO-007"></a>

## REQ-FIFO-007

A read without write while not empty shall decrement usedw_o by one on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_no_wr_rd_normal`

<a id="REQ-FIFO-008"></a>

## REQ-FIFO-008

Simultaneous read and write while neither full nor empty shall hold usedw_o on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_wr_rd_normal`

<a id="REQ-FIFO-009"></a>

## REQ-FIFO-009

A write while full shall not advance wr_ptr on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_wr_on_full`

<a id="REQ-FIFO-010"></a>

## REQ-FIFO-010

A read while empty shall not advance rd_ptr on the next cycle.

- Kind: extracted
- Verified by: `fv/memory/fifo_sva.sv` property `t_rd_on_empty`

# Integration

- Verilator: add `verilator/files/memory.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/memory/fifo.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.

- Upstream entity name matches module name `fifo`.

# Examples

```systemverilog
// Compile verilator/files/memory.f and verilator/colibri.f

fifo #(
  // parameters from Schema
) u_fifo (
  .clk_i (...),
  .reset_i (...),
  .data_i (...),
  .wrreq_i (...),
  .rdreq_i (...),
  .q_o (...),
  .usedw_o (...),
  .empty_o (...),
  .full_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/memory/fifo_tb.sv, fifo_fwft_tb.sv, mixedw_fifo_tb.sv, mixedw_fifo_fwft_tb.sv | fv/memory/fifo_sva.sv (bound on fifo_tb) |

# Agent notes

- Read `src/memory/fifo.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/memory/fifo_tb.sv, fifo_fwft_tb.sv, mixedw_fifo_tb.sv, mixedw_fifo_fwft_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [memory RTL](../../../src/memory/fifo.sv)
- [simulation](../../playbooks/simulation.md)
