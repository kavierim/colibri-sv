---
type: Module
title: decode_8b10b
description: 8b/10b decoder.
tags: [domain:endec, module:decode_8b10b]
status: draft
resource: src/endec/decode_8b10b.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

8b/10b decoder.

# When to use

See the [endec domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Declaration |
| --- |
| (none) |


## Ports

| Declaration |
| --- |
| `input  logic       clk_i` |
| `input  logic [9:0] snk_data_i` |
| `input  logic       snk_valid_i` |
| `output logic [7:0] src_data_o` |
| `output logic       src_control_o, // is K code` |
| `output logic       src_valid_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

8b/10b Decoder lookup table (ROM)-based 8b/10b decoder. The lookup table approach guarantees minimal resource usage and short combinatorial paths. copyright CERN 2025 Changelog: - 0.2 reformatted for Vivado to infer primitives Library entity. Lint alongside verilator/wave0_elab.sv reports multiple tops. 8b/10b tables live in `colibri_common_8b10b`; RLE modules operate on streaming data.

# Integration

- Verilator: add `verilator/files/endec.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/endec/decode_8b10b.sv`.


- Upstream entity name matches module name `decode_8b10b`.

# Examples

```systemverilog
// Compile verilator/files/endec.f and verilator/colibri.f

decode_8b10b #(
  // parameters from Schema
) u_decode_8b10b (
  .clk_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .src_data_o (...),
  .code (...),
  .src_valid_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/endec/decode_8b10b_tb.sv, loopback_8b10b_tb.sv | none |

# Agent notes

- Read `src/endec/decode_8b10b.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/endec/decode_8b10b_tb.sv, loopback_8b10b_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [endec RTL](../../../src/endec/decode_8b10b.sv)
- [simulation](../../playbooks/simulation.md)
