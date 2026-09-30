# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0

"""Behavioral model of src/interfaces/stream/axis_to_avst.sv.

Maps AXI-Stream ``tkeep`` to Avalon-ST ``empty`` using ``g_AVST_ENDIANNESS``
the way the RTL does (REQ-AXIS_TO_AVST-001 .. REQ-AXIS_TO_AVST-004). Packet byte
count is unchanged. ``sop`` follows the idle/last-eop state machine in the RTL.
"""

from __future__ import annotations

from kernel.beat import AvstBeat
from kernel.block import Block
from kernel.channel import Channel


def _swap_endianness(data: int, width: int) -> int:
    if width % 8 != 0:
        raise ValueError("Can't swap endianness if not byte-aligned.")
    n_bytes = width // 8
    out = 0
    for i in range(n_bytes):
        byte = (data >> (i * 8)) & 0xFF
        out |= byte << ((n_bytes - 1 - i) * 8)
    return out


def _keep_to_empty(keep: int, keep_w: int) -> int:
    """RTL keep_to_empty: lowest transition of (keep ^ keep>>1) from the MSB side."""
    if keep == 0:
        raise ValueError("keep cannot be 0")
    onehot = keep ^ (keep >> 1)
    empty = 0
    for i in range(keep_w - 1, -1, -1):
        if onehot & (1 << i):
            empty = keep_w - 1 - i
    return empty


class axis_to_avst(Block):
    """AXI-Stream to Avalon-ST adapter."""

    def __init__(
        self,
        name: str,
        g_DATA_WIDTH: int = 32,
        g_AVST_ENDIANNESS: str = "BIG",
        g_ADD_REGISTERS: bool = True,
    ) -> None:
        super().__init__(name)
        if g_DATA_WIDTH < 8 or g_DATA_WIDTH % 8 != 0:
            raise ValueError("g_DATA_WIDTH must be a positive multiple of 8")
        endian = g_AVST_ENDIANNESS.upper()
        if endian not in ("BIG", "LITTLE"):
            raise ValueError("g_AVST_ENDIANNESS must be 'BIG' or 'LITTLE'")
        self.g_DATA_WIDTH = g_DATA_WIDTH
        self.g_AVST_ENDIANNESS = endian
        self.g_ADD_REGISTERS = g_ADD_REGISTERS
        self._keep_w = g_DATA_WIDTH // 8
        self._snk = Channel(
            "axis",
            data_width=g_DATA_WIDTH,
            keep_width=self._keep_w,
            depth=1,
        )
        self._src = Channel("avst", data_width=g_DATA_WIDTH, depth=1)
        # After reset, next valid beat is start-of-packet (REQ-AXIS_TO_AVST-001).
        self._last_eop = True

    def ports(self) -> dict[str, Channel]:
        return {"snk": self._snk, "src": self._src}

    def step(self) -> None:
        if not self._src.ready:
            return
        beat = self._snk.take()
        if beat is None:
            return
        empty = _keep_to_empty(beat.tkeep, self._keep_w) if beat.tlast else 0
        data = beat.tdata
        if self.g_AVST_ENDIANNESS == "BIG":
            data = _swap_endianness(data, self.g_DATA_WIDTH)
        sop = self._last_eop
        self._last_eop = bool(beat.tlast)
        self._src.accept(
            AvstBeat(data=data, empty=empty, sop=sop, eop=bool(beat.tlast))
        )
