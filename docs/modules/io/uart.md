---
type: Module
title: uart
description: UART transceiver (TX + RX).
tags: [domain:io, module:uart]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
resource: src/io/uart/uart.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

UART transceiver (TX + RX).

# When to use

See the [io domain index](index.md) for siblings and typical compositions.

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
| `input  logic [7:0] tx_data_i` |
| `input  logic       tx_valid_i` |
| `output logic       tx_ready_o` |
| `output logic [7:0] rx_data_o` |
| `output logic       rx_valid_o` |
| `input  logic       rx_pin_i` |
| `output logic       tx_pin_o` |


Width and typing rules: [`CONVENTIONS.md`](../../../CONVENTIONS.md).


# Behaviour

UART Controller module Author: Alberto Perro (alberto.perro at cern.ch) Date: 20-03-2024 Version: 0.1 This module implements a simple uart controller. Release log: - 0.1 first release Pin-level protocols; see area readme for Verilator modelling notes (e.g. I2C SCL release).

# Integration

- Verilator: add `verilator/files/io.f` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `src/io/uart/uart.sv`.


- Upstream entity name matches module name `uart`.

# Examples

```systemverilog
// Compile verilator/files/io.f and verilator/colibri.f

uart #(
  // parameters from Schema
) u_uart (
  .clk_i (...),
  .reset_i (...),
  .tx_data_i (...),
  .tx_valid_i (...),
  .tx_ready_o (...),
  .rx_data_o (...),
  .rx_valid_o (...),
  .rx_pin_i (...),
  .tx_pin_o (...)
);
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/io/uart/uart_tb.sv | none |

# Agent notes

- Read `src/io/uart/uart.sv` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`](../../../CONVENTIONS.md); do not rename ports or packages.
- Run targeted simulation: `sim/io/uart/uart_tb.sv` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

- [io RTL](../../../src/io/uart/uart.sv)
- [simulation](../../playbooks/simulation.md)
