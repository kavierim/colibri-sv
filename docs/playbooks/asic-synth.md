---
type: Playbook
title: ASIC synthesis smoke
description: Yosys read_slang + generic synth check for every src/ module.
tags: [playbook, yosys, asic, synthesis]
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# Purpose

Confirm every SystemVerilog module under `src/` elaborates and maps through Yosys generic `synth` (ASIC-oriented smoke test). This is not a place-and-route or Liberty-tied ASIC flow.

# What PASS means

For each `^module` in `src/**/*.sv` (package-only files such as `binaryio.sv` are skipped as tops):

1. `read_slang -I src --std 1800-2017 --single-unit` on that module plus package sources (`-y` libdirs resolve submodules)
2. `hierarchy -top NAME`
3. `synth -top NAME` (generic only — never `synth_xilinx` / `synth_ice40`)
4. `stat`

Exit code 0 only when every module prints `PASS`.

# Local run

Yosys comes from [oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build) (CI pins release `20260930` / linux-x64). Activate the suite, then from the repository root:

```sh
source /path/to/oss-cad-suite/environment
python3 tools/synth_asic.py
```

Logs go under `build/asic-synth/` (gitignored). Override with `--log-dir` or limit modules with `--module NAME`.

# CI

[`.github/workflows/asic-synth.yml`](../../.github/workflows/asic-synth.yml) downloads the pinned oss-cad-suite build, runs the script, and uploads `build/asic-synth/` as an artifact (including on failure). The Verilator workflow is unchanged.

# Notes

- Yosys does not strip `// xilinx translate_off` comments, so `get_compiler()` stays `AUTO` and `true_dpram` takes the behavioral model. That is acceptable for this smoke test.
- With that path, memories may map to flip-flops rather than RAM macros.
- Package-only files with no `module` (for example `binaryio.sv`) are skipped as tops.
- This smoke is not a Liberty- or SRAM-mapped signoff.
- A synthesis fix must not break `./verilator/run_all.sh`.

# Related

- [simulation](simulation.md)
- [getting-started](getting-started.md)
