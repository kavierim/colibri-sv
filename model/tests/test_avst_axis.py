# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary test code (Apache-2.0); behavioral models use the colibri_sv license.

"""Contract tests for avst_to_axis / axis_to_avst adapters.

REQ-AVST_TO_AXIS-*, REQ-AXIS_TO_AVST-*: adapters preserve packet bytes;
raw AVST↔AXIS connect() is rejected (ConnectError).
"""

from __future__ import annotations

import pytest

from kernel import AvstBeat, Block, Channel, ConnectError, StreamBeat, System
from colibri_model.avst_to_axis import avst_to_axis
from colibri_model.axis_to_avst import axis_to_avst


class _AvstSource(Block):
    def __init__(self, name: str, out: Channel, beats: list[AvstBeat]) -> None:
        super().__init__(name)
        self._out = out
        self._beats = list(beats)

    def ports(self) -> dict[str, Channel]:
        return {"out": self._out}

    def step(self) -> None:
        if self._beats and self._out.ready:
            self._out.accept(self._beats.pop(0))


class _AvstSink(Block):
    def __init__(self, name: str, inp: Channel) -> None:
        super().__init__(name)
        self._in = inp
        self.received: list[AvstBeat] = []

    def ports(self) -> dict[str, Channel]:
        return {"in": self._in}

    def step(self) -> None:
        beat = self._in.take()
        if beat is not None:
            self.received.append(beat)


class _AxisSource(Block):
    def __init__(self, name: str, out: Channel, beats: list[StreamBeat]) -> None:
        super().__init__(name)
        self._out = out
        self._beats = list(beats)

    def ports(self) -> dict[str, Channel]:
        return {"out": self._out}

    def step(self) -> None:
        if self._beats and self._out.ready:
            self._out.accept(self._beats.pop(0))


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


def _avst_bytes(beat: AvstBeat, data_width: int) -> int:
    return max(0, data_width // 8 - beat.empty)


def _axis_bytes(beat: StreamBeat) -> int:
    return max(0, beat.tkeep.bit_count())


def test_connect_raw_avst_to_axis_raises() -> None:
    """Plan contract: AVST meets AXIS only through an adapter block."""
    src = _AvstSource("src", Channel("avst", data_width=32), [])
    dst = _AvstSink("dst", Channel("axis", data_width=32, keep_width=4))
    system = System()
    system.add(src)
    system.add(dst)
    with pytest.raises(ConnectError):
        system.connect(src, "out", dst, "in")


def test_avst_to_axis_then_axis_to_avst_preserves_packet_bytes() -> None:
    """REQ-AVST_TO_AXIS-001/002 and REQ-AXIS_TO_AVST-*: round-trip byte count."""
    width = 32
    keep_w = width // 8
    # 7-byte packet: one full beat + final beat with empty=1 (3 valid bytes).
    packet = [
        AvstBeat(data=0xA0A1A2A3, empty=0, sop=True, eop=False),
        AvstBeat(data=0xB0B1B200, empty=1, sop=False, eop=True),
    ]
    expected_bytes = sum(_avst_bytes(b, width) for b in packet)
    assert expected_bytes == 7

    a2x = avst_to_axis("a2x", g_DATA_WIDTH=width)
    x2a = axis_to_avst("x2a", g_DATA_WIDTH=width)
    src = _AvstSource("src", Channel("avst", data_width=width), packet)
    dst = _AvstSink("dst", Channel("avst", data_width=width))

    system = System()
    system.add(src)
    system.add(a2x)
    system.add(x2a)
    system.add(dst)
    system.connect(src, "out", a2x, "snk")
    system.connect(a2x, "src", x2a, "snk")
    system.connect(x2a, "src", dst, "in")
    report = system.run(40)

    got = sum(_avst_bytes(b, width) for b in dst.received)
    assert got == expected_bytes
    assert report.bytes["src.out"] == expected_bytes
    assert report.bytes["a2x.snk"] == expected_bytes
    assert report.bytes["a2x.src"] == expected_bytes
    assert report.bytes["x2a.snk"] == expected_bytes
    assert report.bytes["x2a.src"] == expected_bytes
    assert report.bytes["dst.in"] == expected_bytes
    assert a2x.ports()["src"].kind == "axis"
    assert a2x.ports()["src"].keep_width == keep_w
    assert x2a.ports()["snk"].kind == "axis"


def test_axis_to_avst_then_avst_to_axis_preserves_packet_bytes() -> None:
    """REQ-AXIS_TO_AVST-001..004 path: AXIS → AVST → AXIS preserves bytes."""
    width = 32
    keep_w = 4
    axis_packet = [
        StreamBeat(tdata=0xA0A1A2A3, tkeep=0b1111, tlast=False),
        StreamBeat(tdata=0xB0B1B200, tkeep=0b0111, tlast=True),
    ]
    expected_bytes = sum(_axis_bytes(b) for b in axis_packet)
    assert expected_bytes == 7

    x2a = axis_to_avst("x2a", g_DATA_WIDTH=width)
    a2x = avst_to_axis("a2x", g_DATA_WIDTH=width)
    src = _AxisSource(
        "src",
        Channel("axis", data_width=width, keep_width=keep_w),
        axis_packet,
    )
    dst = _AxisSink("dst", Channel("axis", data_width=width, keep_width=keep_w))

    system = System()
    system.add(src)
    system.add(x2a)
    system.add(a2x)
    system.add(dst)
    system.connect(src, "out", x2a, "snk")
    system.connect(x2a, "src", a2x, "snk")
    system.connect(a2x, "src", dst, "in")
    report = system.run(40)

    got = sum(_axis_bytes(b) for b in dst.received)
    assert got == expected_bytes
    assert report.bytes["src.out"] == expected_bytes
    assert report.bytes["dst.in"] == expected_bytes
