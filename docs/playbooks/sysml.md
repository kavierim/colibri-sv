# SysML v2 playbook

The structural model comes first. SystemVerilog in `src/` implements it. Observable SHALL text stays in `docs/modules/**/*.md` YAML frontmatter (`requirements[].statement`). The `# Requirements` section holds anchors and verification metadata only. `sysml/requirements.sysml` holds thin stubs (`OKF: path#id` in `doc`, no SHALL sentence). Each implementing `part def` declares `satisfy requirement` usages for its stubs.

The current part definitions are a baseline extracted from the existing RTL on 2026-09-27. That extraction is finished. Do not regenerate the model from `src/`.

## Order of change

1. Edit the `part def` in `sysml/parts/` (ports, parameters, directions).
2. Edit the module page: add `requirements` frontmatter when there is an observable obligation; keep `# Requirements` anchors/metadata; align the Schema table with the part.
3. Add a matching stub in `sysml/requirements.sysml` (`OKF: docs/modules/...#REQ-...` in `doc` only).
4. Add `satisfy requirement REQ_<MODULE>_<NNN>;` on the `part def`.
5. Change `src/`, then `sim/` or `fv/`, so the RTL satisfies the model and the requirement.

`tools/check_sysml_ssot.py` reports divergence. It does not write files.

## Ownership

| Artifact | Role |
| --- | --- |
| `sysml/parts/**/*.sysml` | Structural contract. One `part def` per module, SystemVerilog name (`counter`). |
| `docs/modules/**` | SHALL in frontmatter; assumptions; human-readable Schema |
| `sysml/requirements.sysml` | `REQ-*` stubs with `OKF:` doc pointers |
| `src/**/*.sv` | Implementation of the part |
| `sysml/ArchitectureMeta.sysml`, `sysml/Colibri.sysml` | Metadata and the library index |

Do not add `(* sysml_part *)` pragmas to RTL. Do not copy SHALL sentences into stubs. Do not introduce shared `port def` bundles; keep `snk_*` and `src_*` as separate items so a port name still matches the RTL port name.

## Identifiers

- Defining package is unique per module, `Colibri_<Domain>_<module>` (for example `Colibri_Common_counter`), because one shared package name per file does not parse when the folder is loaded together.
- [`sysml/Colibri.sysml`](../../sysml/Colibri.sysml) re-exports those packages. Stable URI: `sysml://Colibri::Common::counter`. Each part file also contains a usage in the same package (`part wbRamUse : wb_ram`) so the definition is referenced. Add that usage when you add a part.
- Requirement: `REQ-<MODULE>-<NNN>` (`REQ-COUNTER-001`). One observable SHALL per heading, English, on ports or a named bound signal.
- Assumption: `ASM-<MODULE>-<NNN>` on the module page only. It is not a `requirement def`.
- Anchor: `<a id="REQ-COUNTER-001"></a>` immediately before the matching `##` heading.
- `model:` in the page frontmatter is the URI above.

## Port syntax

`in item` / `out item` / `inout item`. A non-trivial SystemVerilog type also has `attribute <port>_sv : String` with the declaration fragment. Integer and boolean parameter defaults are `Integer` and `Boolean`. Other defaults are `String` holding the SystemVerilog expression.

## Licencing

| Output | Header |
| --- | --- |
| `sysml/parts/**` | CERN-OHL-W. The part repeats the design's ports. |
| `sysml/requirements.sysml`, `ArchitectureMeta.sysml`, `Colibri.sysml`, `tools/check_sysml_ssot.py` | Kari ancillary only |

## Check

```sh
uv run python tools/check_sysml_ssot.py
```

Golden requirement page: [`docs/modules/common/counter.md`](../modules/common/counter.md). Identifier reconciliation: [req-okf-reconciliation](../reference/req-okf-reconciliation.md).

## Module page shape

Frontmatter (when requirements exist):

```yaml
provenance:
  upstream_path: gitlab.com/colibri-cern/colibri
  pinned_commit: <sha>
requirements:
  - id: REQ-MODULE-001
    statement: <one SHALL sentence>
```

After `# Behaviour`:

```markdown
# Requirements

SHALL sentences are in YAML frontmatter (`requirements[].statement`).

<a id="REQ-MODULE-001"></a>

## REQ-MODULE-001

- Kind: extracted
- Verified by: `fv/.../module_sva.sv` property `name`
```

On the matching `part def`:

```sysml
private import Colibri_Requirements::*;
// ...
satisfy requirement REQ_MODULE_001;
```

A requirement is a sentence about observable behaviour. A `$fatal` format string or a pasted PSL fragment is not a requirement. Write the sentence in frontmatter, then point at the property or test that checks it.

## Rollout to other modules

Do **not** add empty `requirements:` lists or placeholder REQ ids to structure-only modules. When a module gains `fv/` or self-checking `sim/` collateral, add frontmatter entries, body anchors, stubs, and `satisfy` on the part in one change. Phased migration is recommended; only [`counter`](../modules/common/counter.md) is fully wired today.
