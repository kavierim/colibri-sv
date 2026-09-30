# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0

"""Avalon-ST header prepender (header_add).

Prepends ``snk_header``, sampled at input start-of-packet, to each packet.
Satisfies REQ-HEADER_ADD-001, REQ-HEADER_ADD-002, and REQ-HEADER_ADD-003.
"""

from __future__ import annotations

from collections import deque

from kernel import AvstBeat, Block, Channel


class header_add(Block):
    """Prepend a fixed header to each Avalon-ST packet."""

    def __init__(
        self,
        name: str,
        *,
        g_HEADER_BYTES: int = 14,
        g_DATA_WIDTH: int = 32,
        clk_hz: int | None = None,
    ) -> None:
        super().__init__(name)
        if g_DATA_WIDTH % 8 != 0:
            raise ValueError("g_DATA_WIDTH must be a multiple of 8")
        if g_HEADER_BYTES < 1:
            raise ValueError("g_HEADER_BYTES must be >= 1")
        self.g_HEADER_BYTES = g_HEADER_BYTES
        self.g_DATA_WIDTH = g_DATA_WIDTH
        self._word_bytes = g_DATA_WIDTH // 8
        self.snk = Channel("avst", g_DATA_WIDTH, clk_hz=clk_hz)
        self.src = Channel("avst", g_DATA_WIDTH, clk_hz=clk_hz)
        # Sideband sampled at SOP (RTL snk_header_i).
        self.snk_header = 0
        self._tx_q: deque[AvstBeat] = deque()
        self._buf: list[int] = []
        self._sop_next = True

    def ports(self) -> dict[str, Channel]:
        return {"snk": self.snk, "src": self.src}

    def _header_bytes(self, header: int) -> list[int]:
        out: list[int] = []
        for i in range(self.g_HEADER_BYTES):
            shift = 8 * (self.g_HEADER_BYTES - 1 - i)
            out.append((header >> shift) & 0xFF)
        return out

    def _beat_bytes(self, beat: AvstBeat) -> list[int]:
        n_valid = self._word_bytes if not beat.eop else self._word_bytes - int(beat.empty)
        if n_valid < 0:
            n_valid = 0
        out: list[int] = []
        for i in range(n_valid):
            shift = 8 * (self._word_bytes - 1 - i)
            out.append((beat.data >> shift) & 0xFF)
        return out

    def _pack(self, chunk: list[int], *, sop: bool, eop: bool) -> AvstBeat:
        data = 0
        for i, byte in enumerate(chunk):
            shift = 8 * (self._word_bytes - 1 - i)
            data |= (byte & 0xFF) << shift
        empty = (self._word_bytes - len(chunk)) if eop else 0
        return AvstBeat(data=data, empty=empty, sop=sop, eop=eop)

    def _flush(self, *, final: bool) -> None:
        while len(self._buf) >= self._word_bytes:
            chunk = self._buf[: self._word_bytes]
            del self._buf[: self._word_bytes]
            is_eop = final and not self._buf
            self._tx_q.append(self._pack(chunk, sop=self._sop_next, eop=is_eop))
            self._sop_next = False
            if is_eop:
                self._sop_next = True
                return
        if final and self._buf:
            chunk = self._buf[:]
            self._buf.clear()
            self._tx_q.append(self._pack(chunk, sop=self._sop_next, eop=True))
            self._sop_next = True

    def step(self) -> None:
        if self._tx_q:
            if self.src.ready:
                self.src.accept(self._tx_q.popleft())
            return

        beat = self.snk.take()
        if beat is None:
            return
        if not isinstance(beat, AvstBeat):
            raise TypeError("header_add snk requires AvstBeat")

        if beat.sop:
            self._buf.extend(self._header_bytes(self.snk_header))
            self._sop_next = True
        self._buf.extend(self._beat_bytes(beat))
        self._flush(final=beat.eop)

        if self._tx_q and self.src.ready:
            self.src.accept(self._tx_q.popleft())
