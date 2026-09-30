# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0

"""Contract tests for the shared model kernel."""

from __future__ import annotations

import pytest

from kernel import AvstBeat, Block, Channel, ConnectError, StreamBeat, System


class _Source(Block):
    """Pushes queued beats onto an output channel, one per cycle."""

    def __init__(self, name: str, out: Channel, beats: list) -> None:
        super().__init__(name)
        self._out = out
        self._beats = list(beats)

    def ports(self) -> dict[str, Channel]:
        return {"out": self._out}

    def step(self) -> None:
        if self._beats:
            self._out.accept(self._beats.pop(0))


class _Sink(Block):
    """Drains an input channel into a received list."""

    def __init__(self, name: str, inp: Channel) -> None:
        super().__init__(name)
        self._in = inp
        self.received: list = []

    def ports(self) -> dict[str, Channel]:
        return {"in": self._in}

    def step(self) -> None:
        beat = self._in.take()
        if beat is not None:
            self.received.append(beat)


def test_connect_rejects_data_width_mismatch() -> None:
    src = _Source("src", Channel("axis", data_width=32, keep_width=4), [])
    dst = _Sink("dst", Channel("axis", data_width=64, keep_width=8))
    system = System()
    system.add(src)
    system.add(dst)
    with pytest.raises(ConnectError):
        system.connect(src, "out", dst, "in")


def test_connect_rejects_kind_mismatch() -> None:
    # AvstBeat documents the AVST payload; connect still fails on kind alone.
    _ = AvstBeat(data=0, empty=0, sop=True, eop=True)
    src = _Source("src", Channel("avst", data_width=32), [])
    dst = _Sink("dst", Channel("axis", data_width=32, keep_width=4))
    system = System()
    system.add(src)
    system.add(dst)
    with pytest.raises(ConnectError):
        system.connect(src, "out", dst, "in")


def test_channel_accepts_at_most_one_beat_per_cycle() -> None:
    ch = Channel("axis", data_width=32, keep_width=4)
    beat_a = StreamBeat(tdata=0x11, tkeep=0b1111, tlast=False)
    beat_b = StreamBeat(tdata=0x22, tkeep=0b1111, tlast=True)
    assert ch.accept(beat_a) is True
    assert ch.accept(beat_b) is False
    assert ch.beats == 1


def test_system_run_moves_one_beat_per_cycle() -> None:
    beats = [
        StreamBeat(tdata=0xA, tkeep=0b1111, tlast=False),
        StreamBeat(tdata=0xB, tkeep=0b1111, tlast=True),
    ]
    src = _Source("src", Channel("axis", data_width=32, keep_width=4), beats)
    dst = _Sink("dst", Channel("axis", data_width=32, keep_width=4))
    system = System()
    system.add(src)
    system.add(dst)
    system.connect(src, "out", dst, "in")
    system.run(1)
    assert src._out.beats == 1
    assert dst._in.beats == 1
    assert len(dst.received) == 0  # sink sees transfer on the next cycle
    system.run(1)
    assert len(dst.received) == 1
    assert dst.received[0].tdata == 0xA


def test_axis_byte_count_is_tkeep_popcount() -> None:
    ch = Channel("axis", data_width=32, keep_width=4)
    beat = StreamBeat(tdata=0xDEADBEEF, tkeep=0b0101, tlast=True)
    assert ch.accept(beat) is True
    assert ch.bytes == 2


def test_bits_per_sec_with_clk_hz() -> None:
    ch = Channel("axis", data_width=32, keep_width=4, clk_hz=100_000_000)
    beat = StreamBeat(tdata=0, tkeep=0b1111, tlast=True)
    assert ch.accept(beat) is True
    ch.tick()
    assert ch.cycles == 1
    assert ch.bytes == 4
    assert ch.bits_per_sec == pytest.approx((4 / 1) * 8 * 100_000_000)


def test_bits_per_sec_none_without_clk_hz() -> None:
    ch = Channel("axis", data_width=32, keep_width=4, clk_hz=None)
    beat = StreamBeat(tdata=0, tkeep=0b1111, tlast=True)
    assert ch.accept(beat) is True
    ch.tick()
    assert ch.cycles > 0
    assert ch.bits_per_sec is None
