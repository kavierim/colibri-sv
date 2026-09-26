---
type: Package
title: colibri_utils
description: Bit-math, registers, and byte manipulation.
tags: [package, pkg:utils]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
resource: src/common/utils.sv
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---

# Purpose

Bit-math, registers, and byte manipulation.

SystemVerilog package translated from the upstream VHDL library `colibri`. Import with `import colibri_utils::*;` after compiling `src/common/utils.sv`.

# When to use

Compile this package before any module that imports it. Shared packages are listed in `verilator/colibri.f` in dependency order. Do not rename packages; see [`CONVENTIONS.md`](../../CONVENTIONS.md).

# Schema

Public API is defined in `src/common/utils.sv`. Use the source file as the authoritative list of types, functions, and constants.

# Behaviour

Package functions are either constant functions or class methods per [`CONVENTIONS.md`](../../CONVENTIONS.md). Simulation-only tasks (e.g. `colibri_binaryio`) are not synthesisable.

# Integration

- Add `src/common/utils.sv` via `verilator/colibri.f` or the domain-specific `.f` file that pulls it in.
- VHDL name mapping: see the frozen package table in [`CONVENTIONS.md`](../../CONVENTIONS.md).

# Examples

```systemverilog
import colibri_utils::*;
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| yes | sim/common/utils_tb.sv | fv/common/utils_sva.sv |

# Agent notes

- Treat `src/common/utils.sv` as a frozen API surface unless the user explicitly requests a breaking change.
- Run package testbenches under `sim/` when changing behaviour.

# Related

- [packages index](index.md)
- [getting started](../playbooks/getting-started.md)
