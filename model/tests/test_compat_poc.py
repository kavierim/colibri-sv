# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary test. Does not add a pyproject dependency on PoC_sv.

"""Cross-repo chain: header_add → avst_to_axis → axi4stream_FIFO.

Uses Colibri blocks plus PoC FIFO via sibling ``PoC_sv/model`` on sys.path.
Skipped when that tree is missing.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from kernel import AvstBeat, Block, Channel, StreamBeat, System
from colibri_model.avst_to_axis import avst_to_axis
from colibri_model.header_add import header_add

_POC_MODEL = Path(__file__).resolve().parents[3] / "PoC_sv" / "model"
if _POC_MODEL.is_dir():
    sys.path.insert(0, str(_POC_MODEL))

pytest.importorskip("poc_model.axi4stream_FIFO", reason="PoC_sv/model not on path")

from poc_model.axi4stream_FIFO import axi4stream_FIFO  # noqa: E402


class _AvstSource(Block):
    def __init__(self, name: str, out: Channel, beats: list[AvstBeat]) -> None:
        super().__init__(name)
        self._out = out
        self._beats = list(beats)

    def ports(self) -> dict[str, Channel]:
        return {"out": self._out}

    def step(self) -> None:
        if self._beats and self._out.ready:
            if self._out.accept(self._beats[0]):
                self._beats.pop(0)


class _AxisSink(Block):
    def __init__(self, name: str, inp: Channel) -> None:
        super().__init__(name)
        self._in = inp
        self.received: list[StreamBeat] = []

    def ports(self) -> dict[str, Channel]:
        return {"in": self._in}

    def step(self) -> None:
        beat = self._in.take()
        if beat is not None:
            self.received.append(beat)


def _pack_payload(data: list[int], data_width: int) -> list[AvstBeat]:
    wb = data_width // 8
    beats: list[AvstBeat] = []
    for i in range(0, len(data), wb):
        chunk = data[i : i + wb]
        word = 0
        for bi, val in enumerate(chunk):
            word |= (val & 0xFF) << ((wb - 1 - bi) * 8)
        empty = wb - len(chunk)
        beats.append(
            AvstBeat(
                data=word,
                empty=empty,
                sop=(i == 0),
                eop=(i + wb >= len(data)),
            )
        )
    return beats


def _axis_byte_count(beats: list[StreamBeat]) -> int:
    return sum(max(0, b.tkeep.bit_count()) for b in beats)


def test_header_add_avst_to_axis_fifo_preserves_bytes_and_one_beat_per_cycle() -> None:
    """Payload+header byte count at FIFO Out; one AXIS beat/cycle when not backpressured."""
    width = 32
    header_bytes = [0xAA, 0xBB, 0xCC, 0xDD]
    payload = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16]
    expected_after_header = len(header_bytes) + len(payload)

    hdr = header_add(
        "hdr",
        g_HEADER_BYTES=len(header_bytes),
        g_DATA_WIDTH=width,
    )
    header_int = 0
    for b in header_bytes:
        header_int = (header_int << 8) | (b & 0xFF)
    hdr.snk_header = header_int

    a2x = avst_to_axis("a2x", g_DATA_WIDTH=width)
    # Match avst_to_axis AXIS side (id/dest/user width 0; keep = data/8).
    fifo = axi4stream_FIFO(
        "fifo",
        FRAMES=4,
        MAX_PACKET_DEPTH=8,
        DATA_BITS=width,
        KEEP_BITS=0,
        ID_BITS=0,
        DEST_BITS=0,
        USER_BITS=0,
    )

    src = _AvstSource(
        "src",
        Channel("avst", data_width=width),
        _pack_payload(payload, width),
    )
    sink = _AxisSink(
        "sink",
        Channel(
            "axis",
            data_width=width,
            keep_width=width // 8,
            id_width=0,
            dest_width=0,
            user_width=0,
        ),
    )

    system = System()
    system.add(src)
    system.add(hdr)
    system.add(a2x)
    system.add(fifo)
    system.add(sink)
    system.connect(src, "out", hdr, "snk")
    system.connect(hdr, "src", a2x, "snk")
    system.connect(a2x, "src", fifo, "In")
    system.connect(fifo, "Out", sink, "in")
    report = system.run(80)

    assert _axis_byte_count(sink.received) == expected_after_header
    assert report.bytes["fifo.Out"] == expected_after_header

    # Without sink backpressure, AXIS path moves one beat per cycle once flowing.
    axis_src_beats = report.beats["a2x.src"]
    axis_src_cycles = report.cycles["a2x.src"]
    assert axis_src_beats > 0
    # Sustained rate ≤ 1 beat/cycle; with always-ready sink and shallow stages,
    # accepted beats equal the number of outputting cycles once the pipeline fills.
    assert report.beats["a2x.src"] == report.beats["fifo.In"]
    assert report.beats["fifo.Out"] == len(sink.received)
    # One beat moves per cycle on the AXIS side when not backpressured:
    # every accepted beat on a2x.src occurred with ready high continuously.
    assert axis_src_beats <= axis_src_cycles
    # Peak instantaneous rate is 1: no channel reports more beats than cycles.
    for name, beats in report.beats.items():
        assert beats <= report.cycles[name], name
