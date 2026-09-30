# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0

"""Behavioral model of src/interfaces/stream/avst_width_converter.sv.

Preserves packet byte/symbol count across a full conversion. Initiation interval
follows the width ratio: the narrower side consumes or produces more cycles.
Symbols are first-symbol-in-MSB, matching the RTL and UVVM BFM convention.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass

from kernel.beat import AvstBeat
from kernel.block import Block
from kernel.channel import Channel


@dataclass(slots=True)
class _Sym:
    value: int
    sop: bool
    eop: bool


class avst_width_converter(Block):
    """Avalon-ST data-width converter (symbol-preserving gearbox)."""

    def __init__(
        self,
        name: str,
        g_SYM_WIDTH: int = 8,
        g_INPUT_SYM: int = 16,
        g_OUTPUT_SYM: int = 1,
    ) -> None:
        super().__init__(name)
        if g_SYM_WIDTH < 1 or g_INPUT_SYM < 1 or g_OUTPUT_SYM < 1:
            raise ValueError("symbol parameters must be >= 1")
        self.g_SYM_WIDTH = g_SYM_WIDTH
        self.g_INPUT_SYM = g_INPUT_SYM
        self.g_OUTPUT_SYM = g_OUTPUT_SYM
        self._sym_mask = (1 << g_SYM_WIDTH) - 1
        in_w = g_SYM_WIDTH * g_INPUT_SYM
        out_w = g_SYM_WIDTH * g_OUTPUT_SYM
        self._snk = Channel("avst", data_width=in_w, depth=1)
        self._src = Channel("avst", data_width=out_w, depth=1)
        # Enough room for one input beat plus one pending output beat.
        self._cap = g_INPUT_SYM + g_OUTPUT_SYM
        self._buf: deque[_Sym] = deque()

    def ports(self) -> dict[str, Channel]:
        return {"snk": self._snk, "src": self._src}

    def step(self) -> None:
        if len(self._buf) + self.g_INPUT_SYM <= self._cap:
            beat = self._snk.take()
            if beat is not None:
                self._ingest(beat)
        if self._src.ready and self._can_emit():
            self._src.accept(self._emit())

    def _ingest(self, beat: AvstBeat) -> None:
        empty = beat.empty if beat.eop else 0
        n_valid = self.g_INPUT_SYM - empty
        if n_valid < 1:
            raise ValueError("AVST beat has no valid symbols")
        for i in range(n_valid):
            shift = (self.g_INPUT_SYM - 1 - i) * self.g_SYM_WIDTH
            value = (beat.data >> shift) & self._sym_mask
            self._buf.append(
                _Sym(
                    value=value,
                    sop=bool(beat.sop and i == 0),
                    eop=bool(beat.eop and i == n_valid - 1),
                )
            )

    def _can_emit(self) -> bool:
        if not self._buf:
            return False
        limit = min(len(self._buf), self.g_OUTPUT_SYM)
        for i in range(limit):
            if self._buf[i].eop:
                return True
        return len(self._buf) >= self.g_OUTPUT_SYM

    def _emit(self) -> AvstBeat:
        out: list[_Sym] = []
        eop = False
        empty = 0
        for _ in range(self.g_OUTPUT_SYM):
            if not self._buf:
                break
            sym = self._buf.popleft()
            out.append(sym)
            if sym.eop:
                eop = True
                empty = self.g_OUTPUT_SYM - len(out)
                break
        sop = out[0].sop
        data = 0
        for i, sym in enumerate(out):
            shift = (self.g_OUTPUT_SYM - 1 - i) * self.g_SYM_WIDTH
            data |= (sym.value & self._sym_mask) << shift
        return AvstBeat(data=data, empty=empty, sop=sop, eop=eop)
