# Module documentation template (internal)

Use this structure for every `type: Module` concept page. Concept ID = path without `.md`.

```yaml
---
type: Module
title: <module_name>
description: <one line>
tags: [domain:<area>, module:<name>]
status: draft
resource: src/<domain>/<module>.sv
model: sysml://Colibri::<Domain>::<module>   # optional; URI of the part def
---
```

## Required sections

1. **# Purpose**
2. **# When to use**
3. **# Schema** (parameters and ports tables)
4. **# Behaviour**
5. **# Requirements** (optional; add when `fv/` bind or self-checking `sim/` exists — see [sysml playbook](playbooks/sysml.md) and [counter](modules/common/counter.md))
6. **# Assumptions** (optional; only for documented `assume property` collateral, not RTL reads)
7. **# Integration**
8. **# Examples**
9. **# Verification**
10. **# Agent notes**
11. **# Related**

Link using bundle-root paths: `[counter](/modules/common/counter.md)`.
