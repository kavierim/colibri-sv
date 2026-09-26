---
type: Module
title: synchro_handshake
description: Stream CDC with backpressure propagation.
tags: [domain:common, module:synchro_handshake, cdc]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/common/synchro_handshake.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Stream CDC with backpressure propagation.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_DATA_WIDTH = 1` |
| `parameter int g_NUM_STAGES = 2` |


## Ports

| Declaration |
| --- |
| `input  logic                     snk_clk_i` |
| `input  logic                     src_clk_i` |
| `input  logic                     reset_i` |
| `input  logic [g_DATA_WIDTH-1:0]  snk_data_i` |
| `input  logic                     snk_valid_i` |
| `output logic                     snk_ready_o` |
| `output logic [g_DATA_WIDTH-1:0]  src_data_o` |
| `output logic                     src_valid_o` |
| `input  logic                     src_ready_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Clock domain boundary synchronizer with handshake. Synchronizes a data/valid/ready stream with a two-way handshake. Round-trip latency follows g_NUM_STAGES. Minimum latency is 4 clocks for valid and 6 clocks for ready. Intended for signals that change infrequently; a cc_fifo is the high-throughput alternative. VHDL requires g_DATA_WIDTH (no default). Default 1 lets Verilator elaborate this module. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/synchro_handshake.sv`.


- Upstream entity name matches module name `synchro_handshake`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

synchro_handshake #(
  // parameters from Schema
) u_synchro_handshake (
  .snk_clk_i (...),
  .src_clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_valid_o (...),
  .src_ready_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/synchro_handshake_tb.sv | none |

# Agent notes

- Read `src/common/synchro_handshake.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/synchro_handshake_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/synchro_handshake.sv)
- [simulation](../../playbooks/simulation.md)
