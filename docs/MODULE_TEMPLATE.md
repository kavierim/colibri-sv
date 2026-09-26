# Module documentation template (internal)

Use this structure for every `type: Module` concept page. Concept ID = path without `.md`.

```yaml
---
type: Module
title: <module_name>
description: <one line>
tags: [domain:<area>, module:<name>]
generated: { by: <actor>, at: <ISO8601Z> }
status: draft
resource: src/<domain>/<module>.sv
---
```

## Required sections

1. **# Purpose**
2. **# When to use**
3. **# Schema** (parameters and ports tables)
4. **# Behaviour**
5. **# Integration**
6. **# Examples**
7. **# Verification**
8. **# Agent notes**
9. **# Related**

Link using bundle-root paths: `[counter](/modules/common/counter.md)`.
