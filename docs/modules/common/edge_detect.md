---
type: Module
title: edge_detect
description: Rising and falling edge detection.
tags: [domain:common, module:edge_detect]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/common/edge_detect.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Rising and falling edge detection.

RTL notes: Edge detect. Release log: - 0.1 first release

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter logic g_RESET_VAL = 1'b0` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic clk_i` |
| | `input  logic data_i` |
| | `output logic pulse_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Edge detect. Release log: - 0.1 first release See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/edge_detect.sv`.


- Upstream entity name matches module name `edge_detect`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

edge_detect #(
  // parameters from Schema
) u_edge_detect (
  .clk_i (...),
  .data_i (...),
  .pulse_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/edge_detect_tb.sv | fv/common/edge_detect_sva.sv |

# Agent notes

- Read `src/common/edge_detect.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/edge_detect_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/edge_detect.sv)
- [simulation](../../playbooks/simulation.md)
