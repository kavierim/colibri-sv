---
type: Module
title: stream_buffer_generic
description: Same buffer with a parameterized data type.
tags: [domain:common, module:stream_buffer_generic, interface:avst]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/common/stream_buffer_generic.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Same buffer with a parameterized data type.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter type data_t             = logic [7:0]` |
| `parameter bit  g_REGISTER_DATAPATH = 1'b0` |


## Ports

| Declaration |
| --- |
| `input  logic  reset_i` |
| `input  logic  clk_i` |
| `input  data_t snk_data_i` |
| `input  logic  snk_valid_i` |
| `output logic  snk_ready_o` |
| `output data_t src_data_o` |
| `input  logic  src_ready_i` |
| `output logic  src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Simple stream buffer with a generic type. Zero latency (skid) when g_REGISTER_DATAPATH is 0. One clock of latency (pipeline) when g_REGISTER_DATAPATH is 1. VHDL requires data_t (no default). logic [7:0] lets Verilator elaborate this module. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/stream_buffer_generic.sv`.


- Upstream entity name matches module name `stream_buffer_generic`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

stream_buffer_generic #(
  // parameters from Schema
) u_stream_buffer_generic (
  .reset_i (...),
  .clk_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_ready_i (...),
  .src_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/stream_buffer_generic_tb.sv | none |

# Agent notes

- Read `src/common/stream_buffer_generic.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/stream_buffer_generic_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/stream_buffer_generic.sv)
- [simulation](../../playbooks/simulation.md)
