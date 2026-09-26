---
type: Module
title: uart_rx
description: UART receiver only.
tags: [domain:io, module:uart_rx]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/io/uart/uart_rx.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

UART receiver only.

# When to use

Use `uart` for a combined transceiver.

# Schema

## Parameters

| Declaration |
| --- |
| `parameter time g_CLOCK_PERIOD = time'(100ns)` |
| `parameter int unsigned g_BAUD_RATE = 115200` |


## Ports

| Declaration |
| --- |
| `input  logic       clk_i` |
| `input  logic       reset_i` |
| `output logic [7:0] rx_data_o` |
| `output logic       rx_valid_o` |
| `input  logic       rx_pin_i` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

UART receiver module Author: Alberto Perro (alberto.perro at cern.ch) Date: 20-03-2024 Version: 0.1 This module implements a simple uart receiver. Release log: - 0.1 first release Pin-level protocols; see area readme for Verilator modelling notes (e.g. I2C SCL release).

# Integration

- Verilator: add `verilator/files/io.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/io/uart/uart_rx.sv`.


- Upstream entity name matches module name `uart_rx`.

# Examples

```systemverilog
// Compile verilator/files/io.f and verilator/colibri.f

uart_rx #(
  // parameters from Schema
) u_uart_rx (
  .clk_i (...),
  .reset_i (...),
  .rx_data_o (...),
  .rx_valid_o (...),
  .rx_pin_i (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| see area index | none listed | none |

# Agent notes

- Read `src/io/uart/uart_rx.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `none listed` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [io RTL](../../../src/io/uart/uart_rx.sv)
- [simulation](../../playbooks/simulation.md)
