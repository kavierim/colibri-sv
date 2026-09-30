# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0

"""Avalon-ST packet CRC (crc).

Computes the packet CRC described in ``docs/modules/comms/crc.md`` and
``src/comms/crc.sv``. The CRC is presented with the end-of-packet word
(``src_crc``). Polynomial and init/xor/invert follow the SV parameters.
"""

from __future__ import annotations

from kernel import AvstBeat, Block, Channel

# Default matches colibri_poly::c_CRC_8.
_DEFAULT_POLY = 0x07


def _poly_width(poly: int) -> int:
    bits = max(int(poly).bit_length(), 1)
    return (bits + 7) // 8 * 8


def _invert_byte(value: int) -> int:
    result = 0
    for i in range(8):
        if value & (1 << i):
            result |= 1 << (7 - i)
    return result


def _invert_bits(value: int, width: int) -> int:
    result = 0
    for i in range(width):
        if value & (1 << i):
            result |= 1 << (width - 1 - i)
    return result


class crc(Block):
    """CRC over an Avalon-ST packet stream; result on EOP via ``src_crc``."""

    def __init__(
        self,
        name: str,
        *,
        g_DATA_WIDTH: int = 64,
        g_CRC_POLY: int = _DEFAULT_POLY,
        g_INIT_VAL: int = 0,
        g_XOR_OUT: int = 0,
        g_INVERT_IN: bool = False,
        g_INVERT_OUT: bool = False,
        clk_hz: int | None = None,
    ) -> None:
        super().__init__(name)
        if g_DATA_WIDTH % 8 != 0:
            raise ValueError("g_DATA_WIDTH must be a multiple of 8")
        self.g_DATA_WIDTH = g_DATA_WIDTH
        self.g_CRC_POLY = int(g_CRC_POLY)
        self.g_INIT_VAL = int(g_INIT_VAL)
        self.g_XOR_OUT = int(g_XOR_OUT)
        self.g_INVERT_IN = bool(g_INVERT_IN)
        self.g_INVERT_OUT = bool(g_INVERT_OUT)
        self._word_bytes = g_DATA_WIDTH // 8
        self._crc_width = _poly_width(self.g_CRC_POLY)
        self._poly_mask = (1 << self._crc_width) - 1
        self.snk = Channel("avst", g_DATA_WIDTH, clk_hz=clk_hz)
        self.src = Channel("avst", g_DATA_WIDTH, clk_hz=clk_hz)
        # Sideband CRC presented with EOP (RTL src_crc_o).
        self.src_crc = 0
        self._crc = self.g_INIT_VAL & self._poly_mask
        self._hold: AvstBeat | None = None

    def ports(self) -> dict[str, Channel]:
        return {"snk": self.snk, "src": self.src}

    def _beat_bytes(self, beat: AvstBeat) -> list[int]:
        n_valid = self._word_bytes if not beat.eop else self._word_bytes - int(beat.empty)
        if n_valid < 0:
            n_valid = 0
        out: list[int] = []
        for i in range(n_valid):
            shift = 8 * (self._word_bytes - 1 - i)
            out.append((beat.data >> shift) & 0xFF)
        return out

    def _feed_byte(self, byte: int) -> None:
        value = _invert_byte(byte) if self.g_INVERT_IN else byte
        crc = self._crc
        poly = self.g_CRC_POLY & self._poly_mask
        width = self._crc_width
        for bitn in range(7, -1, -1):
            fb = ((crc >> (width - 1)) & 1) ^ ((value >> bitn) & 1)
            crc = ((crc << 1) & self._poly_mask)
            if fb:
                crc ^= poly
        self._crc = crc

    def _finalize_crc(self) -> int:
        crc = self._crc
        if self.g_INVERT_OUT:
            crc = _invert_bits(crc, self._crc_width)
        return (crc ^ (self.g_XOR_OUT & self._poly_mask)) & self._poly_mask

    def step(self) -> None:
        if self._hold is not None:
            if not self.src.ready:
                return
            self.src.accept(self._hold)
            self._hold = None
            return

        if not self.src.ready:
            return

        beat = self.snk.take()
        if beat is None:
            return
        if not isinstance(beat, AvstBeat):
            raise TypeError("crc snk requires AvstBeat")

        if beat.sop:
            self._crc = self.g_INIT_VAL & self._poly_mask

        for byte in self._beat_bytes(beat):
            self._feed_byte(byte)

        out = AvstBeat(
            data=beat.data,
            empty=beat.empty,
            sop=beat.sop,
            eop=beat.eop,
        )
        if beat.eop:
            self.src_crc = self._finalize_crc()
            self._crc = self.g_INIT_VAL & self._poly_mask
        else:
            self.src_crc = 0

        if not self.src.accept(out):
            self._hold = out
