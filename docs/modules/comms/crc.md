---
type: Module
title: crc
description: CRC over an Avalon-ST packet stream.
tags: [domain:comms, module:crc]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: stable
resource: src/comms/crc.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

CRC over an Avalon-ST packet stream.

# When to use

Append or check CRC on an AVST packet stream; polynomial from [`colibri_poly`](../../packages/colibri_poly.md).

# Schema

## Parameters

| Declaration |
| --- |
| `parameter int unsigned g_DATA_WIDTH = 64` |
| `parameter g_CRC_POLY = colibri_poly::c_CRC_8` |
| `parameter g_INIT_VAL = {$bits(g_CRC_POLY){1'b0}}` |
| `parameter g_XOR_OUT = {$bits(g_CRC_POLY){1'b0}}` |
| `parameter bit g_INVERT_IN = 1'b0` |
| `parameter bit g_INVERT_OUT = 1'b0` |


## Ports

| Declaration |
| --- |
| `input  logic                    clk_i` |
| `input  logic                    reset_i` |
| `input  logic [g_DATA_WIDTH-1:0] snk_data_i` |
| `input  logic                    snk_sop_i` |
| `input  logic                    snk_eop_i` |
| `input  logic [colibri_types::avst_empty_width(g_DATA_WIDTH, 8)-1:0] snk_empty_i` |
| `input  logic                    snk_valid_i` |
| `output logic                    snk_ready_o` |
| `output logic [g_DATA_WIDTH-1:0] src_data_o` |
| `output logic                    src_sop_o` |
| `output logic                    src_eop_o` |
| `output logic [colibri_types::avst_empty_width(g_DATA_WIDTH, 8)-1:0] src_empty_o` |
| `output logic                    src_valid_o` |
| `input  logic                    src_ready_i` |
| `output logic [$bits(g_CRC_POLY)-1:0] src_crc_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Cyclic redundancy check for a packet stream. The CRC is presented with the end-of-packet word. Computes CRC over the AVST packet on the fly; configure polynomial width and init via generics. Typically sits before [`be_add_trail`](../misc/be_add_trail.md) or after payload logic.

# Integration

- Verilator: add `verilator/files/comms.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/comms/crc.sv`.


- Upstream entity name matches module name `crc`.

# Examples

```systemverilog
// Compile verilator/files/comms.f and verilator/colibri.f

crc #(
  // parameters from Schema
) u_crc (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_sop_i (...),
  .snk_eop_i (...),
  .snk_empty_i (...),
  .snk_valid_i (...),
  .snk_ready_o (...),
  .src_data_o (...),
  .src_sop_o (...),
  .src_eop_o (...),
  .src_empty_o (...),
  .src_valid_o (...),
  .src_ready_i (...),
  .src_crc_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/comms/crc_tb.sv | none |

# Agent notes

- Read `src/comms/crc.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/comms/crc_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [comms RTL](../../../src/comms/crc.sv)
- [simulation](../../playbooks/simulation.md)
