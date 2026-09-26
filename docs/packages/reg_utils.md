---
type: Package
title: reg_utils
description: CSR field read/write helpers.
tags: [package, reg_utils]
status: draft
resource: src/misc/mmap_fifo/vhdl_if/reg_utils.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

CSR field read/write helpers.

SystemVerilog package translated from the upstream VHDL library `colibri`. Import with `import reg_utils::*;` after compiling `src/misc/mmap_fifo/vhdl_if/reg_utils.sv`.

# When to use

Compile this package before any module that imports it. Shared packages are listed in `verilator/colibri.f` in dependency order. Do not rename packages; see [`CONVENTIONS.md`](../../CONVENTIONS.md).

# Schema

Public API is defined in `src/misc/mmap_fifo/vhdl_if/reg_utils.sv`. Use the source file as the authoritative list of types, functions, and constants.

# Behaviour

Package functions are either constant functions or class methods per [`CONVENTIONS.md`](../../CONVENTIONS.md). Simulation-only tasks (e.g. `colibri_binaryio`) are not synthesisable.

# Integration

- Add `src/misc/mmap_fifo/vhdl_if/reg_utils.sv` via `verilator/colibri.f` or the domain-specific `.f` file that pulls it in.
- VHDL name mapping: see the frozen package table in [`CONVENTIONS.md`](../../CONVENTIONS.md).

# Examples

```systemverilog
import reg_utils::*;
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | see sim/ | none |

# Agent notes

- Treat `src/misc/mmap_fifo/vhdl_if/reg_utils.sv` as a frozen API surface unless the user explicitly requests a breaking change.
- Run package testbenches under `sim/` when changing behaviour.

# Related

- [packages index](index.md)
- [getting started](../playbooks/getting-started.md)
