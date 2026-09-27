---
type: Module
title: counter
description: Simple counter with optional modulo and enable.
tags: [domain:common, module:counter]
status: stable
resource: src/common/counter.sv
model: sysml://Colibri::Common::counter
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
requirements:
  - id: REQ-COUNTER-001
    statement: On the cycle after reset_i is released, value_o and wraparound_o shall be 0.
  - id: REQ-COUNTER-002
    statement: When reset_i is low and enable_i is low, the internal count register shall hold its value on the next clock edge.
  - id: REQ-COUNTER-003
    statement: When g_MODULO is greater than zero, reset_i is low, and enable_i is high, the internal count register shall increment by one on the next clock edge while it is not already at the last code g_MODULO - 1.
  - id: REQ-COUNTER-004
    statement: When g_MODULO is greater than zero, reset_i is low, and enable_i is high with the internal count register at the last code, the next clock edge shall clear the register to zero and wraparound_o shall have been high in the previous cycle.
---

# Purpose

Simple counter with optional modulo and enable.

# When to use

Basic timed/event counting; set `g_MODULO` and width explicitly for wrap behaviour.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_MODULO = 0` |
| `parameter int unsigned g_COUNTER_WIDTH = colibri_utils::log2ceil(int'(g_MODULO))` |


## Ports

| Declaration |
| --- |
| `input  logic clk_i` |
| `input  logic reset_i` |
| `input  logic enable_i` |
| `output logic [((g_COUNTER_WIDTH > 0) ? g_COUNTER_WIDTH : 1)-1:0] value_o` |
| `output logic wraparound_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Simple Counter Some of the work was inspired by the PoC Library (https://github.com/VLSI-EDA/PoC) Release log: - 0.2 Modify g_MODULO behavior to avoid integer limits at 32 bits - 0.1 first release Style reference for later modules. See CONVENTIONS.md. See RTL for clocking; not every block has `reset_i`.

# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.

<a id="REQ-COUNTER-001"></a>

## REQ-COUNTER-001

- Kind: extracted
- Verified by: `fv/common/counter_sva.sv` property `t_valid_reset`

<a id="REQ-COUNTER-002"></a>

## REQ-COUNTER-002

- Kind: extracted
- Verified by: `fv/common/counter_sva.sv` property `t_not_counting`

<a id="REQ-COUNTER-003"></a>

## REQ-COUNTER-003

- Kind: extracted
- Verified by: `fv/common/counter_sva.sv` property `t_count`

<a id="REQ-COUNTER-004"></a>

## REQ-COUNTER-004

- Kind: extracted
- Verified by: `fv/common/counter_sva.sv` property `t_wraparound`

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/counter.sv`.


- Upstream entity name matches module name `counter`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

counter #(
  // parameters from Schema
) u_counter (
  .clk_i (...),
  .reset_i (...),
  .enable_i (...),
  .value_o (...),
  .wraparound_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/counter_tb.sv | fv/common/counter_sva.sv |

# Agent notes

- Read `src/common/counter.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/counter_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/counter.sv)
- [simulation](../../playbooks/simulation.md)
