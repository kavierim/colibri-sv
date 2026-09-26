---
type: Module
title: debouncer
description: Input debouncer.
tags: [domain:common, module:debouncer]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/common/debouncer.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Input debouncer.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter g_RESET_VAL              = 1'b0` |
| `parameter time g_DEBOUNCE_TIME     = 10ms` |
| `parameter time g_CLOCK_PERIOD      = 10ns` |


## Ports

| Declaration |
| --- |
| `input  logic                          clk_i` |
| `input  logic                          reset_i` |
| `input  logic [$bits(g_RESET_VAL)-1:0] data_i` |
| `output logic [$bits(g_RESET_VAL)-1:0] data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Debouncer. Release log: - 0.1 first release g_RESET_VAL is an unconstrained std_logic_vector in VHDL. data_i and data_o take $bits(g_RESET_VAL); pass a sized vector. g_CLOCK_PERIOD has no VHDL default; 10 ns is only so Verilator can elaborate this module. See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/debouncer.sv`.


- Upstream entity name matches module name `debouncer`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

debouncer #(
  // parameters from Schema
) u_debouncer (
  .clk_i (...),
  .reset_i (...),
  .data_i (...),
  .data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/debouncer_tb.sv | fv/common/debouncer_sva.sv |

# Agent notes

- Read `src/common/debouncer.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/debouncer_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/debouncer.sv)
- [simulation](../../playbooks/simulation.md)
