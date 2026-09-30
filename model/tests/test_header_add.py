# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0

"""Behavioral tests for colibri_model.header_add (REQ-HEADER_ADD-*)."""

from __future__ import annotations

from colibri_model.header_add import header_add
from kernel import AvstBeat, Block, Channel, System


def _word_bytes(data_width: int) -> int:
    return data_width // 8


def _pack_bytes(data: list[int], data_width: int) -> list[AvstBeat]:
    """Pack payload bytes into MSB-first Avalon-ST beats (Colibri convention)."""
    wb = _word_bytes(data_width)
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


def _unpack_beats(beats: list[AvstBeat], data_width: int) -> list[int]:
    """Extract valid bytes from Avalon-ST beats (empty applies on EOP only)."""
    wb = _word_bytes(data_width)
    out: list[int] = []
    for beat in beats:
        n = (wb - beat.empty) if beat.eop else wb
        for bi in range(n):
            out.append((beat.data >> ((wb - 1 - bi) * 8)) & 0xFF)
    return out


class _Source(Block):
    """Pushes queued beats onto an output channel, one per cycle when ready."""

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


class _Sink(Block):
    """Drains an input channel into a received list."""

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


def _run_header_add(
    *,
    g_data_width: int,
    g_header_bytes: int,
    header_bytes: list[int],
    payload: list[int],
    cycles: int,
) -> list[int]:
    assert len(header_bytes) == g_header_bytes
    header_int = 0
    for b in header_bytes:
        header_int = (header_int << 8) | (b & 0xFF)

    dut = header_add(
        "dut",
        g_HEADER_BYTES=g_header_bytes,
        g_DATA_WIDTH=g_data_width,
    )
    # snk_header is sampled at input SOP (RTL snk_header_i / Behaviour).
    dut.snk_header = header_int

    src = _Source(
        "src",
        Channel("avst", data_width=g_data_width),
        _pack_bytes(payload, g_data_width),
    )
    sink = _Sink("sink", Channel("avst", data_width=g_data_width))

    system = System()
    system.add(src)
    system.add(dut)
    system.add(sink)
    system.connect(src, "out", dut, "snk")
    system.connect(dut, "src", sink, "in")
    system.run(cycles)
    return _unpack_beats(sink.received, g_data_width)


def test_header_add_prepends_once_and_keeps_payload() -> None:
    """REQ-HEADER_ADD-001 / Behaviour: header is inserted once in front of the packet.

    Output byte stream shall be configured header followed by every payload byte
    with nothing dropped (module page Behaviour; REQ-HEADER_ADD-001 SOP on first
    presented beat of an idle packet).
    """
    g_data_width = 8
    header_bytes = [0xAA, 0xBB, 0xCC, 0xDD]
    payload = [0x10, 0x20, 0x30, 0x40, 0x50]
    got = _run_header_add(
        g_data_width=g_data_width,
        g_header_bytes=len(header_bytes),
        header_bytes=header_bytes,
        payload=payload,
        cycles=64,
    )
    assert got == header_bytes + payload


def test_header_add_sop_only_on_first_output_beat() -> None:
    """REQ-HEADER_ADD-001 and REQ-HEADER_ADD-002: sop high only on first beat.

    When the output packet starts, src_sop shall be high on the first presented
    beat and low on subsequent multi-beat words.
    """
    g_data_width = 8
    header_bytes = [0x01, 0x02]
    payload = [0x11, 0x22, 0x33]
    header_int = (0x01 << 8) | 0x02

    dut = header_add("dut", g_HEADER_BYTES=2, g_DATA_WIDTH=g_data_width)
    dut.snk_header = header_int
    src = _Source(
        "src",
        Channel("avst", data_width=g_data_width),
        _pack_bytes(payload, g_data_width),
    )
    sink = _Sink("sink", Channel("avst", data_width=g_data_width))
    system = System()
    system.add(src)
    system.add(dut)
    system.add(sink)
    system.connect(src, "out", dut, "snk")
    system.connect(dut, "src", sink, "in")
    system.run(64)

    assert sink.received, "expected output beats"
    assert sink.received[0].sop is True
    for beat in sink.received[1:]:
        assert beat.sop is False
    assert sink.received[-1].eop is True


def test_header_add_empty_on_last_beat() -> None:
    """REQ-HEADER_ADD-003: on the last beat, empty is less than a full word.

    With a non-multiple-of-word packet length, the EOP beat shall report empty
    for the unused trailing bytes.
    """
    g_data_width = 32
    header_bytes = [0xDE, 0xAD, 0xBE, 0xEF]
    # Header (4) + payload (5) = 9 bytes → last 32-bit beat has empty=3.
    payload = [0x01, 0x02, 0x03, 0x04, 0x05]
    got = _run_header_add(
        g_data_width=g_data_width,
        g_header_bytes=4,
        header_bytes=header_bytes,
        payload=payload,
        cycles=64,
    )
    assert got == header_bytes + payload

    # Re-run to inspect empty on the captured EOP beat.
    header_int = 0
    for b in header_bytes:
        header_int = (header_int << 8) | b
    dut = header_add("dut", g_HEADER_BYTES=4, g_DATA_WIDTH=g_data_width)
    dut.snk_header = header_int
    src = _Source(
        "src",
        Channel("avst", data_width=g_data_width),
        _pack_bytes(payload, g_data_width),
    )
    sink = _Sink("sink", Channel("avst", data_width=g_data_width))
    system = System()
    system.add(src)
    system.add(dut)
    system.add(sink)
    system.connect(src, "out", dut, "snk")
    system.connect(dut, "src", sink, "in")
    system.run(64)
    eop = sink.received[-1]
    assert eop.eop is True
    assert eop.empty < _word_bytes(g_data_width)
