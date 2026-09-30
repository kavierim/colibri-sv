# Behavioral model playbook

Python models under `model/` exercise stream and packet composition before RTL changes. The shared kernel (`model/kernel/`) is ancillary Apache-2.0 text, identical in spirit to `PoC_sv/model/kernel/`. Behavioral blocks in `colibri_model/` are CERN-OHL-W.

This library and `PoC_sv/model` do **not** import each other. The optional cross-repo test `model/tests/test_compat_poc.py` adds `PoC_sv/model` to `sys.path` when that sibling tree is present; neither `pyproject.toml` depends on the other repo.

## Cycle model

- One `System.run(n)` advances `n` cycles.
- A beat moves when the source has data and the destination is ready; at most one beat is accepted on a channel per cycle.
- Channels count beats, bytes (`tkeep` or AVST `empty`), and cycles. Optional `clk_hz` yields bits per second on the report.

## Stream beats

| Kind | Beat type | Payload fields |
| --- | --- | --- |
| AXI-Stream (`axis`) | `StreamBeat` | `tdata`, `tkeep`, `tlast`, `tid`, `tdest`, `tuser` |
| Avalon-ST (`avst`) | `AvstBeat` | `data`, `empty`, `sop`, `eop` |

`Valid`/`Ready` is the channel handshake, not a beat field.

## Connect rules

`System.connect` rejects width or kind mismatches. AVST meets AXIS only via [`avst_to_axis`](../modules/interfaces/avst_to_axis.md) / [`axis_to_avst`](../modules/interfaces/axis_to_avst.md). Adapters preserve packet byte count.

## Runnable Colibri blocks

| Module | Class |
| --- | --- |
| [`header_add`](../modules/packet/header_add.md) | `colibri_model.header_add.header_add` |
| [`crc`](../modules/comms/crc.md) | `colibri_model.crc.crc` |
| [`fifo`](../modules/memory/fifo.md) | `colibri_model.fifo.fifo` |
| [`avst_width_converter`](../modules/interfaces/avst_width_converter.md) | `colibri_model.avst_width_converter.avst_width_converter` |
| [`avst_to_axis`](../modules/interfaces/avst_to_axis.md) | `colibri_model.avst_to_axis.avst_to_axis` |
| [`axis_to_avst`](../modules/interfaces/axis_to_avst.md) | `colibri_model.axis_to_avst.axis_to_avst` |

## Licences

| Tree | Licence |
| --- | --- |
| `model/colibri_model/**` | CERN-OHL-W |
| `model/kernel/**` | Ancillary Apache-2.0 (shared text with PoC) |
| `model/tests/**` | Ancillary Apache-2.0 |

## Check

```sh
cd model
uv run pytest
```
