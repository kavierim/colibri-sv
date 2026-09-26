---
type: Module
title: bit_shifter
description: Arbitrary bit shift on a stream.
tags: [domain:comms, module:bit_shifter]
status: draft
resource: src/comms/bit_shifter.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Arbitrary bit shift on a stream.

# When to use

See the [comms domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_DATA_WIDTH = 8` |
| `parameter bit          g_MSB_RIGHT = 1'b1` |


## Ports

| Declaration |
| --- |
| `input  logic                                                          clk_i` |
| `input  logic                                                          reset_i` |
| `input  logic [colibri_utils::downto_width(colibri_utils::log2ceil(int'(g_DATA_WIDTH)))-1:0] offset_i` |
| `input  logic [g_DATA_WIDTH-1:0]                                       data_i` |
| `output logic [g_DATA_WIDTH-1:0]                                       data_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Bit-shift a continuous stream. g_MSB_RIGHT 1 joins the new word on the MSB side. g_MSB_RIGHT 0 joins it on the LSB side. The output uses the registered offset. Stream-facing modules use Avalon-ST records from `colibri_types` unless the RTL exposes a simple valid/ready bus.

# Integration

- Verilator: add `verilator/files/comms.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/comms/bit_shifter.sv`.


- Upstream entity name matches module name `bit_shifter`.

# Examples

```systemverilog
// Compile verilator/files/comms.f and verilator/colibri.f

bit_shifter #(
  // parameters from Schema
) u_bit_shifter (
  .clk_i (...),
  .reset_i (...),
  .offset_i (...),
  .data_i (...),
  .data_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/comms/bit_shifter_tb.sv | none |

# Agent notes

- Read `src/comms/bit_shifter.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/comms/bit_shifter_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [comms RTL](../../../src/comms/bit_shifter.sv)
- [simulation](../../playbooks/simulation.md)
