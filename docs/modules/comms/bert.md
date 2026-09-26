---
type: Module
title: bert
description: PRBS bit-error-rate tester.
tags: [domain:comms, module:bert]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/comms/bert.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

PRBS bit-error-rate tester.

RTL notes: Bit error rate tester. A PRBS scrambler feeds the DUT; g_DUT_DELAY absorbs the loopback latency before statistics are counted.

# When to use

See the [comms domain index](index.md) for siblings and typical compositions.

# Schema

## Parameters

| Parameter | Declaration |
| --- | --- |
| | `parameter int unsigned g_DATA_WIDTH = 32` |
| | `parameter int unsigned g_STATS_WIDTH = 64` |
| | `parameter g_PRBS_POLY = colibri_poly::c_PRBS_7` |
| | `parameter int unsigned g_DUT_DELAY = 1` |


## Ports

| Port | Declaration |
| --- | --- |
| | `input  logic                     clk_i` |
| | `input  logic                     reset_i` |
| | `input  logic [g_DATA_WIDTH-1:0]  snk_data_i` |
| | `input  logic                     snk_valid_i` |
| | `output logic [g_DATA_WIDTH-1:0]  src_data_o` |
| | `output logic                     src_valid_o` |
| | `output logic [g_STATS_WIDTH-1:0] bit_errors_o` |
| | `output logic [g_STATS_WIDTH-1:0] total_bits_o` |
| | `output logic [g_STATS_WIDTH-1:0] word_errors_o` |
| | `output logic [g_STATS_WIDTH-1:0] invalid_words_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

Bit error rate tester. A PRBS scrambler feeds the DUT; g_DUT_DELAY absorbs the loopback latency before statistics are counted. Stream-facing modules use Avalon-ST records from `colibri_types` unless the RTL exposes a simple valid/ready bus.

# Integration

- Verilator: add `verilator/files/comms.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/comms/bert.sv`.


- Upstream entity name matches module name `bert`.

# Examples

```systemverilog
// Compile verilator/files/comms.f and verilator/colibri.f

bert #(
  // parameters from Schema
) u_bert (
  .clk_i (...),
  .reset_i (...),
  .snk_data_i (...),
  .snk_valid_i (...),
  .src_data_o (...),
  .src_valid_o (...),
  .bit_errors_o (...),
  .total_bits_o (...),
  .word_errors_o (...),
  .invalid_words_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/comms/bert_tb.sv | none |

# Agent notes

- Read `src/comms/bert.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/comms/bert_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [comms RTL](../../../src/comms/bert.sv)
- [simulation](../../playbooks/simulation.md)
