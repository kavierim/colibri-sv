# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary test code (Apache-2.0); behavioral models use the colibri_sv license.

"""Contract tests for colibri_model.fifo (REQ-FIFO-*)."""

from __future__ import annotations

from kernel import AvstBeat, Block, Channel, System
from colibri_model.fifo import fifo


class _AvstSource(Block):
    """Pushes queued AVST beats onto an output channel, one per cycle."""

    def __init__(self, name: str, out: Channel, beats: list[AvstBeat]) -> None:
        super().__init__(name)
        self._out = out
        self._beats = list(beats)

    def ports(self) -> dict[str, Channel]:
        return {"out": self._out}

    def step(self) -> None:
        # Backpressure: leave the beat queued when the channel is not ready.
        if self._beats and self._out.ready:
            self._out.accept(self._beats.pop(0))


class _AvstSink(Block):
    """Drains an AVST input; optional stall_cycles before accepting."""

    def __init__(
        self,
        name: str,
        inp: Channel,
        *,
        stall_cycles: int = 0,
    ) -> None:
        super().__init__(name)
        self._in = inp
        self._stall_left = stall_cycles
        self.received: list[AvstBeat] = []

    def ports(self) -> dict[str, Channel]:
        return {"in": self._in}

    def step(self) -> None:
        if self._stall_left > 0:
            self._stall_left -= 1
            return
        beat = self._in.take()
        if beat is not None:
            self.received.append(beat)


def _word(data: int, *, sop: bool = False, eop: bool = False, empty: int = 0) -> AvstBeat:
    return AvstBeat(data=data, empty=empty, sop=sop, eop=eop)


def test_fifo_preserves_order() -> None:
    """REQ-FIFO-006/007: words progress in write order through the FIFO."""
    depth = 4
    width = 8
    words = [_word(i, sop=(i == 0), eop=(i == 7)) for i in range(8)]
    dut = fifo("dut", g_NUM_WORDS=depth, g_INPUT_WIDTH=width, g_OUTPUT_WIDTH=width)
    src = _AvstSource(
        "src",
        Channel("avst", data_width=width),
        words,
    )
    dst = _AvstSink("dst", Channel("avst", data_width=width))
    system = System()
    system.add(src)
    system.add(dut)
    system.add(dst)
    system.connect(src, "out", dut, "snk")
    system.connect(dut, "src", dst, "in")
    system.run(40)
    assert [b.data for b in dst.received] == list(range(8))
    assert len(dst.received) == 8


def test_fifo_full_applies_backpressure_no_drops() -> None:
    """REQ-FIFO-005/009: when usedw equals g_NUM_WORDS, full blocks further writes."""
    depth = 4
    width = 8
    # More beats than depth; sink stalls long enough to fill the FIFO.
    payload = [_word(0x10 + i, sop=(i == 0), eop=(i == 9)) for i in range(10)]
    dut = fifo("dut", g_NUM_WORDS=depth, g_INPUT_WIDTH=width, g_OUTPUT_WIDTH=width)
    src = _AvstSource("src", Channel("avst", data_width=width), payload)
    # Stall sink so the FIFO fills; Channel.ready on snk must go low (depth).
    dst = _AvstSink(
        "dst",
        Channel("avst", data_width=width),
        stall_cycles=20,
    )
    system = System()
    system.add(src)
    system.add(dut)
    system.add(dst)
    system.connect(src, "out", dut, "snk")
    system.connect(dut, "src", dst, "in")

    system.run(12)
    snk = dut.ports()["snk"]
    assert snk.depth == depth  # depth follows g_NUM_WORDS
    assert not snk.ready  # full → backpressure
    queued_before_drain = len(src._beats)
    assert queued_before_drain > 0  # unsent beats retained (no drop)

    system.run(80)
    assert [b.data for b in dst.received] == [0x10 + i for i in range(10)]
    assert len(dst.received) == 10
    assert src._beats == []


def test_fifo_depth_follows_g_num_words() -> None:
    """REQ-FIFO-005: capacity is g_NUM_WORDS (snk Channel.depth)."""
    for n in (2, 4, 8):
        dut = fifo("dut", g_NUM_WORDS=n, g_INPUT_WIDTH=16, g_OUTPUT_WIDTH=16)
        assert dut.ports()["snk"].depth == n
