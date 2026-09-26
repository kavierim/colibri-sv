---
type: Module
title: meta_buffer
description: Metadata buffer in the RX datapath.
tags: [domain:aurora, module:meta_buffer]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/proto/aurora_64b66b/include/meta_buffer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Metadata buffer in the RX datapath.

# When to use

See the [aurora_64b66b domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_DATA_WIDTH = 2` |


## Ports

| Declaration |
| --- |
| `input  logic                          clk_i` |
| `input  logic                          reset_i` |
| `input  logic [g_DATA_WIDTH-1:0]       snk_data_i` |
| `input  logic                          snk_valid_i` |
| `output logic                          snk_ready_o` |
| `output logic                          src_valid_o` |
| `input  logic                          src_ready_i` |
| `output logic [g_DATA_WIDTH-1:0]       src_data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Metadata propagation buffer. Buffer to propagate metadata in pipelined streams. changelog: - 0.1: initial release Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/include/meta_buffer.sv`.


- Upstream entity name matches module name `meta_buffer`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

meta_buffer #(
  // parameters from Schema
) u_meta_buffer (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .src_data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/include/meta_buffer.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/include/meta_buffer.sv)
- [simulation](../../../playbooks/simulation.md)
