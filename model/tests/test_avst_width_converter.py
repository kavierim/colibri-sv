# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary test code (Apache-2.0); behavioral models use the colibri_sv license.

"""Contract tests for colibri_model.avst_width_converter.

Module page has no REQ-* IDs; asserts match documented byte / packet behaviour.
"""

from __future__ import annotations

import pytest

from kernel import AvstBeat, Block, Channel, System
from colibri_model.avst_width_converter import avst_width_converter


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


def _avst_bytes(beat: AvstBeat, data_width: int) -> int:
    return max(0, data_width // 8 - beat.empty)


def _run_converter(
    *,
    g_SYM_WIDTH: int,
    g_INPUT_SYM: int,
    g_OUTPUT_SYM: int,
    beats: list[AvstBeat],
    cycles: int,
) -> tuple[list[AvstBeat], object]:
    in_w = g_SYM_WIDTH * g_INPUT_SYM
    out_w = g_SYM_WIDTH * g_OUTPUT_SYM
    dut = avst_width_converter(
        "dut",
        g_SYM_WIDTH=g_SYM_WIDTH,
        g_INPUT_SYM=g_INPUT_SYM,
        g_OUTPUT_SYM=g_OUTPUT_SYM,
    )
    src = _AvstSource("src", Channel("avst", data_width=in_w), beats)
    dst = _AvstSink("dst", Channel("avst", data_width=out_w))
    system = System()
    system.add(src)
    system.add(dut)
    system.add(dst)
    system.connect(src, "out", dut, "snk")
    system.connect(dut, "src", dst, "in")
    report = system.run(cycles)
    return dst.received, report


def test_width_converter_bytes_in_equal_bytes_out() -> None:
    """Same packet byte count on snk and src (symbol width unchanged)."""
    # 4 symbols in → 1 symbol out: pack 4 narrow beats into one wide beat path reversed.
    # Use wide→narrow: 4×8-bit symbols in, 1×8-bit symbol out.
    g_SYM, g_IN, g_OUT = 8, 4, 1
    in_w = g_SYM * g_IN
    # One full beat (4 bytes) then EOP with empty=0.
    beats = [
        AvstBeat(data=0x01020304, empty=0, sop=True, eop=True),
    ]
    received, report = _run_converter(
        g_SYM_WIDTH=g_SYM,
        g_INPUT_SYM=g_IN,
        g_OUTPUT_SYM=g_OUT,
        beats=beats,
        cycles=40,
    )
    in_bytes = sum(_avst_bytes(b, in_w) for b in beats)
    out_w = g_SYM * g_OUT
    out_bytes = sum(_avst_bytes(b, out_w) for b in received)
    assert out_bytes == in_bytes == 4
    assert report.bytes["src.out"] == report.bytes["dut.snk"]
    assert report.bytes["dut.src"] == report.bytes["dut.snk"]


def test_narrower_input_takes_more_cycles_than_wider_output() -> None:
    """Narrower side needs more beat-cycles; bytes/beat (= throughput) is lower."""
    g_SYM = 8
    payload_bytes = 16
    narrow_in, wide_out = 1, 4

    beats_n = [
        AvstBeat(
            data=i & 0xFF,
            empty=0,
            sop=(i == 0),
            eop=(i == payload_bytes - 1),
        )
        for i in range(payload_bytes)
    ]
    recv_n, report_n = _run_converter(
        g_SYM_WIDTH=g_SYM,
        g_INPUT_SYM=narrow_in,
        g_OUTPUT_SYM=wide_out,
        beats=beats_n,
        cycles=80,
    )
    out_w = g_SYM * wide_out
    assert sum(_avst_bytes(b, out_w) for b in recv_n) == payload_bytes

    # Same converter: narrow snk issues more beats than wide src for one payload.
    assert report_n.beats["dut.snk"] > report_n.beats["dut.src"]
    assert report_n.beats["dut.snk"] == payload_bytes
    assert report_n.beats["dut.src"] == payload_bytes // wide_out
    # Throughput as bytes per beat-cycle (accepted beat).
    snk_bpc = report_n.bytes["dut.snk"] / report_n.beats["dut.snk"]
    src_bpc = report_n.bytes["dut.src"] / report_n.beats["dut.src"]
    assert snk_bpc < src_bpc
    assert snk_bpc == pytest.approx(narrow_in)  # 1 byte/beat
    assert src_bpc == pytest.approx(wide_out)  # 4 bytes/beat

    # Wider input needs fewer input beats than the narrow-input path.
    wide_in, narrow_out = 4, 1
    in_w_w = g_SYM * wide_in
    beats_w = [
        AvstBeat(data=0x00010203, empty=0, sop=True, eop=False),
        AvstBeat(data=0x04050607, empty=0, sop=False, eop=False),
        AvstBeat(data=0x08090A0B, empty=0, sop=False, eop=False),
        AvstBeat(data=0x0C0D0E0F, empty=0, sop=False, eop=True),
    ]
    assert sum(_avst_bytes(b, in_w_w) for b in beats_w) == payload_bytes
    recv_w, report_w = _run_converter(
        g_SYM_WIDTH=g_SYM,
        g_INPUT_SYM=wide_in,
        g_OUTPUT_SYM=narrow_out,
        beats=beats_w,
        cycles=80,
    )
    assert sum(_avst_bytes(b, g_SYM * narrow_out) for b in recv_w) == payload_bytes
    assert report_n.beats["dut.snk"] > report_w.beats["dut.snk"]
