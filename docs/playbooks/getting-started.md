---
type: Playbook
title: Getting started
description: Licence, repository layout, and first module integration.
tags: [playbook, onboarding]
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
3. Pull in RTL using one of:
   - [`colibri.f`](../../colibri.f) (full library, dependency order), or
   - [`Bender.yml`](../../Bender.yml) / [`colibri.core`](../../colibri.core) — see [package managers](package-managers.md), or
   - `verilator/colibri.f` plus a domain list (e.g. `verilator/files/common.f`) for a smaller subset.
4. Import packages with `import colibri_utils::*;` and `import colibri_types::*;` as needed.
5. Run `./verilator/run_all.sh` in this repository to confirm tool versions match CI.

# Licence

CERN-OHL-W-2.0. See `LICENSES/CERN-OHL-W-2.0.txt` and [`NOTICE`](../../NOTICE).

# Related

- [package-managers](package-managers.md)
- [simulation](simulation.md)
- [stream-interfaces](stream-interfaces.md)
