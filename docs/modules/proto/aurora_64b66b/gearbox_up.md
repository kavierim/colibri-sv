---
type: Module
title: gearbox_up
description: Continuous upscaling gearbox (RX path).
tags: [domain:aurora, module:gearbox_up]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/proto/aurora_64b66b/rx/gearbox_up.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Continuous upscaling gearbox (RX path).

# When to use

Aurora RX upscaler; not [`comms/gearbox`](../../comms/gearbox.md).

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_INPUT_WIDTH` |
| `parameter int g_OUTPUT_WIDTH` |


## Ports

| Declaration |
| --- |
| `input  logic                         clk_i` |
| `input  logic                         reset_i` |
| `input  logic                         slip_i` |
| `input  logic [g_INPUT_WIDTH-1:0]     snk_data_i` |
| `input  logic                         snk_valid_i` |
| `output logic [g_OUTPUT_WIDTH-1:0]    src_data_o` |
| `output logic                         src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../../CONVENTIONS.md).


# Behaviour

Continuous Stream Upsizing Gearbox. Generic upscaling gearbox for continuous streams on a single clock domain. It includes a slip signal to shift the output (1 bit resolution). Inspired by the work of Timon Heim for Yarr. changelog: - 0.1: initial release Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.

# Integration

- Verilator: add `verilator/files/aurora.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/proto/aurora_64b66b/rx/gearbox_up.sv`.


- Upstream entity name matches module name `gearbox_up`.

# Examples

```systemverilog
// Compile verilator/files/aurora.f and verilator/colibri.f

gearbox_up #(
  // parameters from Schema
) u_gearbox_up (
  .clk_i (...),
  .reset_i (...),
  .slip_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .src_data_o (...),
  .src_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/proto/aurora_64b66b/rx/gearbox_up.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [proto/aurora_64b66b RTL](../../../../src/proto/aurora_64b66b/rx/gearbox_up.sv)
- [simulation](../../../playbooks/simulation.md)
