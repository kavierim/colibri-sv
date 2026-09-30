# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0

"""Behavioral model of src/interfaces/stream/avst_to_axis.sv.

Maps Avalon-ST ``empty`` to AXI-Stream ``tkeep`` using ``g_AVST_ENDIANNESS``
the way the RTL does (REQ-AVST_TO_AXIS-001, REQ-AVST_TO_AXIS-002). Packet byte
count is unchanged. ``tid``/``tdest``/``tuser`` default to 0.
"""

from __future__ import annotations

from kernel.beat import StreamBeat
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


def _empty_to_keep(empty: int, keep_w: int) -> int:
    """RTL empty_to_keep: tkeep[i]=1 for i < keep_w - empty."""
    n = keep_w - empty
    if n < 0:
        n = 0
    return (1 << n) - 1 if n else 0


class avst_to_axis(Block):
    """Avalon-ST to AXI-Stream adapter."""

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
        self._snk = Channel("avst", data_width=g_DATA_WIDTH, depth=1)
        self._src = Channel(
            "axis",
            data_width=g_DATA_WIDTH,
            keep_width=self._keep_w,
            depth=1,
        )

    def ports(self) -> dict[str, Channel]:
        return {"snk": self._snk, "src": self._src}

    def step(self) -> None:
        if not self._src.ready:
            return
        beat = self._snk.take()
        if beat is None:
            return
        if beat.eop and beat.empty != 0:
            tkeep = _empty_to_keep(beat.empty, self._keep_w)
        else:
            tkeep = (1 << self._keep_w) - 1
        tdata = beat.data
        if self.g_AVST_ENDIANNESS == "BIG":
            tdata = _swap_endianness(tdata, self.g_DATA_WIDTH)
        self._src.accept(
            StreamBeat(
                tdata=tdata,
                tkeep=tkeep,
                tlast=bool(beat.eop),
                tid=0,
                tdest=0,
                tuser=0,
            )
        )
