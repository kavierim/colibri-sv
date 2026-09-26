---
type: Playbook
title: Agent workflow
description: How coding agents read and update the documentation bundle.
tags: [playbook, agents]
generated: { by: process:generate_doc_bundle/1.0, at: 2026-09-26T11:42:07Z }
status: draft
sources:
  - id: upstream
    resource: https://gitlab.com/colibri-cern/colibri/-/tree/3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
    title: Upstream VHDL at pin commit
---
# Bundle root

Documentation lives in [`docs/`](../index.md). RTL remains in `src/`.

# Editing modules

1. Read the module documentation page and its `resource` RTL file.
2. Follow [`docs/MODULE_TEMPLATE.md`](../MODULE_TEMPLATE.md) when creating or restructuring pages.
3. Update the domain [`index.md`](../modules/index.md) if `description` changes.
4. Append significant changes to [`log.md`](../log.md).

# Parallel ownership

Claim one domain under `docs/modules/<domain>/` per change set to avoid merge conflicts.

# Verification

After RTL edits, run the listed testbench or `./verilator/run_all.sh`.

# Related

- [`AGENTS.md`](../../AGENTS.md)
- [`.cursor/skills/documentation/project.md`](../../.cursor/skills/documentation/project.md)
