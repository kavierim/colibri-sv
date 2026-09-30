# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0

"""Behavioral tests for colibri_model.crc (module Behaviour / crc.sv).

The crc module page has no REQ-* anchors; tests follow Behaviour and the
RTL contract: CRC over the AVST packet, presented with the EOP word.
Polynomial default is colibri_poly::c_CRC_8 = 8'h07.
"""

from __future__ import annotations

from colibri_model.crc import crc
from kernel import AvstBeat, Block, Channel, System

# colibri_poly::c_CRC_8
CRC8_POLY = 0x07


def _word_bytes(data_width: int) -> int:
    return data_width // 8


def _invert_byte(b: int) -> int:
    return int(f"{b & 0xFF:08b}"[::-1], 2)


def _invert_bits(value: int, width: int) -> int:
    return int(f"{value & ((1 << width) - 1):0{width}b}"[::-1], 2)


def expected_crc(
    data: list[int],
    *,
    poly: int = CRC8_POLY,
    width: int = 8,
    init: int = 0,
    xor_out: int = 0,
    invert_in: bool = False,
    invert_out: bool = False,
) -> int:
    """Independent MSB-first CRC matching sim/comms/crc_tb.sv (not the model)."""
    mask = (1 << width) - 1
    crc_v = init & mask
    for byte in data:
        b = _invert_byte(byte) if invert_in else (byte & 0xFF)
        for bitn in range(7, -1, -1):
            fb = ((crc_v >> (width - 1)) & 1) ^ ((b >> bitn) & 1)
            crc_v = ((crc_v << 1) & mask)
            if fb:
                crc_v ^= poly
    if invert_out:
        crc_v = _invert_bits(crc_v, width)
    return crc_v ^ (xor_out & mask)


def _pack_bytes(data: list[int], data_width: int) -> list[AvstBeat]:
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
    wb = _word_bytes(data_width)
    out: list[int] = []
    for beat in beats:
        n = (wb - beat.empty) if beat.eop else wb
        for bi in range(n):
            out.append((beat.data >> ((wb - 1 - bi) * 8)) & 0xFF)
    return out


class _Source(Block):
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


def test_crc_matches_independent_oracle_and_passes_payload() -> None:
    """Behaviour: CRC over the packet; presented with EOP; payload unchanged.

    Default polynomial is CRC-8 (0x07), init/xor_out zero, no bit invert.
    Oracle is implemented in this test file (expected_crc), not via the model.
    """
    g_data_width = 8
    payload = [0x01, 0x02, 0x03, 0x04, 0x05]
    oracle = expected_crc(payload, poly=CRC8_POLY, width=8)

    dut = crc(
        "dut",
        g_DATA_WIDTH=g_data_width,
        g_CRC_POLY=CRC8_POLY,
        g_INIT_VAL=0,
        g_XOR_OUT=0,
        g_INVERT_IN=False,
        g_INVERT_OUT=False,
    )
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

    got_bytes = _unpack_beats(sink.received, g_data_width)
    assert got_bytes == payload, "CRC block must not drop or alter packet bytes"
    assert sink.received[-1].eop is True
    assert dut.src_crc == oracle


def test_crc_on_wider_word_with_partial_last_beat() -> None:
    """Behaviour: CRC covers only valid bytes (empty on EOP); poly still CRC-8."""
    g_data_width = 32
    payload = [0x10, 0x20, 0x30]  # one beat, empty=1
    oracle = expected_crc(payload, poly=CRC8_POLY, width=8)

    dut = crc(
        "dut",
        g_DATA_WIDTH=g_data_width,
        g_CRC_POLY=CRC8_POLY,
        g_INIT_VAL=0,
        g_XOR_OUT=0,
        g_INVERT_IN=False,
        g_INVERT_OUT=False,
    )
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
    system.run(32)

    assert _unpack_beats(sink.received, g_data_width) == payload
    assert sink.received[-1].eop is True
    assert sink.received[-1].empty == 1
    assert dut.src_crc == oracle
