---
type: Playbook
title: Package managers and integration
description: FuseSoC, Bender, and simulator file lists for adopting colibri-sv.
tags: [playbook, integration, fusesoc, bender, verilator]
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# Purpose

Integrate the full RTL library into FPGA, ASIC, or Verilator flows without hand-maintaining compile order.

# Manifests at repository root

| File | Role |
| --- | --- |
| [`colibri.f`](../../colibri.f) | Complete `src/` file list in dependency order plus `+incdir+src` |
| [`Bender.yml`](../../Bender.yml) | [Bender](https://github.com/pulp-platform/bender) package `colibri-sv` |
| [`colibri.core`](../../colibri.core) | FuseSoC CAPI=2 core `kavierim:colibri:sv:0.1.0` |

Compile order matches the existing Verilator domain lists under `verilator/files/*.f` (packages and `colibri_*` names per [`CONVENTIONS.md`](../../CONVENTIONS.md)).

# Bender

Add a path or git dependency in your top-level `Bender.yml`:

```yaml
dependencies:
  colibri-sv:
    path: ../colibri_sv   # or git: https://github.com/kavierim/colibri-sv.git
```

Dependents receive `export_include_dirs: [src]`. List RTL in your own target with `bender sources` or let your flow consume the merged file list.

# FuseSoC

Register the repository, then depend on the core from a fileset:

```yaml
# your_project.core (fragment)
filesets:
  rtl:
    depend:
      - kavierim:colibri:sv:0.1.0
```

- **`default` target** — RTL fileset only (integration builds).
- **`sim` target** — RTL plus every `sim/` file. Default tool is Verilator in `binary` mode (`--binary`) with `--timing` and `--assert`. One run elaborates a single top (`top_module`, default `counter_tb`). Bound checkers and the rest of the suite stay in [`verilator/run_all.sh`](../../verilator/run_all.sh).

Example:

```sh
fusesoc run --target=sim kavierim:colibri:sv:0.1.0 --top_module=counter_tb
```

# Simulator file list (`colibri.f`)

From the `colibri_sv` root:

```sh
verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-MULTITOP -f colibri.f
```

Add your DUT wrapper and testbench after the file list, or pass `-f colibri.f` together with project-specific sources.

# Verilator regression in this repository

CI and local regression do **not** use the root `colibri.f` alone. They use [`verilator/colibri.f`](../../verilator/colibri.f) (wave-0 packages) plus per-domain lists — see [simulation](simulation.md). That keeps compile times lower and matches bound SVA under `fv/`.

When you add RTL, update the matching `verilator/files/<domain>.f` block, then regenerate the root manifests:

```sh
python tools/gen_packaging.py
```

The script concatenates `verilator/colibri.f` and `verilator/files/*.f` in the same order as `run_all.sh` and checks that every `src/**/*.sv` file is listed once.

# Related

- [getting-started](getting-started.md)
- [simulation](simulation.md)
