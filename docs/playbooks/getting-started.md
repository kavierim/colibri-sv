---
type: Playbook
title: Getting started
description: Licence, repository layout, and first module integration.
tags: [playbook, onboarding]
generated: { by: process:generate_okf_bundle/1.0, at: 2026-09-26T11:35:23Z }
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# Purpose

Adopt Colibri SystemVerilog modules in a Verilator 5 project.

# Steps

1. Read [`CONVENTIONS.md`](../../CONVENTIONS.md) for naming, packages, and stream types.
2. Pick a module from [modules index](../modules/index.md) or [packages](../packages/index.md).
3. Add `verilator/colibri.f` plus the domain file list (e.g. `verilator/files/common.f`) to your compile script.
4. Import packages with `import colibri_utils::*;` and `import colibri_types::*;` as needed.
5. Run `./verilator/run_all.sh` in this repository to confirm tool versions match CI.

# Licence

CERN-OHL-W-2.0. See `LICENSES/CERN-OHL-W-2.0.txt` and [`NOTICE`](../../NOTICE).

# Related

- [simulation](simulation.md)
- [stream-interfaces](stream-interfaces.md)
