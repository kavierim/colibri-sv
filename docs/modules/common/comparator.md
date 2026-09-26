---
type: Module
title: comparator
description: Comparator with enable.
tags: [domain:common, module:comparator]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/common/comparator.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Comparator with enable.

RTL notes: Simple Comparator. Asserts a_gt_b_o when a is greater than b, and only while enable is high. g_IS_EQUAL selects a greater-or-equal compare. The result is delayed one cycle.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int g_DATA_WIDTH = 32` |
| | `parameter bit g_IS_EQUAL   = 1'b0` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                    clk_i` |
| | `input  logic                    enable_i` |
| | `input  logic [g_DATA_WIDTH-1:0] a_i` |
| | `input  logic [g_DATA_WIDTH-1:0] b_i` |
| | `output logic                    a_gt_b_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Simple Comparator. Asserts a_gt_b_o when a is greater than b, and only while enable is high. g_IS_EQUAL selects a greater-or-equal compare. The result is delayed one cycle. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/comparator.sv`.


- Upstream entity name matches module name `comparator`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

comparator #(
  // parameters from Schema
) u_comparator (
  .clk_i (...),
  .enable_i (...),
  .a_i (...),
  .b_i (...),
  .a_gt_b_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/comparator_tb.sv | none |

# Agent notes

- Read `src/common/comparator.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/comparator_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/comparator.sv)
- [simulation](../../playbooks/simulation.md)
