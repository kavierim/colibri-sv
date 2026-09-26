---
type: Module
title: frequency_counter
description: Measure an input clock against a reference.
tags: [domain:misc, module:frequency_counter]
status: draft
resource: src/misc/frequency_counter.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Measure an input clock against a reference.

# When to use

See the [misc domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_CLK_REF_FREQ_HZ = 100_000_000` |
| `parameter int unsigned g_NUM_CLOCKS     = 1` |
| `parameter int unsigned g_DATA_WIDTH     = 32` |
| `parameter int unsigned g_SAMPLE_FREQ_HZ = 1` |


## Ports

| Declaration |
| --- |
| `input  logic clk_ref_i` |
| `input  logic reset_i` |
| `input  logic [g_NUM_CLOCKS-1:0] clk_meas_i` |
| `output `COLIBRI_UNS_ARRAY(freq_data_o, 0, g_NUM_CLOCKS - 1, g_DATA_WIDTH)` |
| `output logic [g_NUM_CLOCKS-1:0] freq_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Frequency counter. Measures arbitrary clocks against a known reference and returns the frequency in Hz. Many blocks are Avalon-ST packet manipulators or Wishbone bridges.

# Integration

- Verilator: add `verilator/files/misc.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/misc/frequency_counter.sv`.

Import [`colibri_types`](../../packages/colibri_types.md) when the ports use AVST/AXIS structs.


- Upstream entity name matches module name `frequency_counter`.

# Examples

```systemverilog
// Compile verilator/files/misc.f and verilator/colibri.f

frequency_counter #(
  // parameters from Schema
) u_frequency_counter (
  .clk_ref_i (...),
  .reset_i (...),
  .clk_meas_i (...),
  .freq_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/misc/frequency_counter_tb.sv | none |

# Agent notes

- Read `src/misc/frequency_counter.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/misc/frequency_counter_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [misc RTL](../../../src/misc/frequency_counter.sv)
- [simulation](../../playbooks/simulation.md)
