---
type: Module
title: synchro_pulse
description: Pulse synchronizer across clock domains.
tags: [domain:common, module:synchro_pulse, cdc]
status: draft
resource: src/common/synchro_pulse.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Pulse synchronizer across clock domains.

# When to use

See the [common domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int g_NUM_STAGES = 2` |


## Ports

| Declaration |
| --- |
| `input  logic src_clk_i` |
| `input  logic dst_clk_i` |
| `input  logic pulse_i` |
| `output logic pulse_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Synchronizes fast pulses over clock domain boundaries. Pulses from the source clock become single-cycle pulses in the destination domain, independent of the clock-frequency relation. Destination pulses are one cycle wide regardless of the source pulse width. There should be at least 2 destination clock cycles between consecutive source pulses. Work inspired from the article "Crossing the abyss: asynchronous signals in a synchronous world" By Mike Stein, Paradigm Works, available at https://www.edn.com/crossing-the-abyss-asynchronous-signals-in-a-synchronous-world/ See RTL for clocking; not every block has `reset_i`.

# Integration

- Verilator: add `verilator/files/common.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/common/synchro_pulse.sv`.


- Upstream entity name matches module name `synchro_pulse`.

# Examples

```systemverilog
// Compile verilator/files/common.f and verilator/colibri.f

synchro_pulse #(
  // parameters from Schema
) u_synchro_pulse (
  .src_clk_i (...),
  .dst_clk_i (...),
  .pulse_i (...),
  .pulse_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/synchro_pulse_tb.sv | none |

# Agent notes

- Read `src/common/synchro_pulse.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/common/synchro_pulse_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [common domain](index.md)
- [common RTL](../../../src/common/synchro_pulse.sv)
- [simulation](../../playbooks/simulation.md)
