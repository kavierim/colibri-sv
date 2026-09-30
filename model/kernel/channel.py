# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary kernel shared by colibri_sv/model and PoC_sv/model. Behavioral models use each repo license.

"""Single-cycle stream channel with beat/byte/cycle counters."""

from __future__ import annotations

from collections import deque
from typing import Deque, Literal

from kernel.beat import AvstBeat, StreamBeat

Beat = StreamBeat | AvstBeat
Kind = Literal["axis", "avst"]


def _axis_bytes(beat: StreamBeat, data_width: int, keep_width: int | None) -> int:
    if keep_width:
        return max(0, beat.tkeep.bit_count())
    return max(0, data_width // 8)


def _avst_bytes(beat: AvstBeat, data_width: int) -> int:
    return max(0, data_width // 8 - beat.empty)


class Channel:
    """Buffered link with handshake and throughput counters."""

    def __init__(
        self,
        kind: Kind,
        data_width: int,
        keep_width: int | None = None,
        id_width: int = 0,
        dest_width: int = 0,
        user_width: int = 0,
        clk_hz: int | None = None,
        depth: int = 1,
    ) -> None:
        if kind not in ("axis", "avst"):
            raise ValueError(f"kind must be 'axis' or 'avst', got {kind!r}")
        if depth < 1:
            raise ValueError("depth must be >= 1")
        self.kind: Kind = kind
        self.data_width = data_width
        self.keep_width = keep_width
        self.id_width = id_width
        self.dest_width = dest_width
        self.user_width = user_width
        self.clk_hz = clk_hz
        self.depth = depth
        self.beats = 0
        self.bytes = 0
        self.cycles = 0
        self._slots: Deque[Beat] = deque()
        self._accepted_this_cycle = False

    @property
    def ready(self) -> bool:
        """False when the buffer is full (depth occupied)."""
        return len(self._slots) < self.depth

    @property
    def bits_per_sec(self) -> float | None:
        if self.clk_hz is None or self.cycles == 0:
            return None
        return (self.bytes / self.cycles) * 8 * self.clk_hz

    def tick(self) -> None:
        """Record one clock cycle (idle or active) and clear per-cycle accept latch."""
        self.cycles += 1
        self._accepted_this_cycle = False

    def accept(self, beat: Beat) -> bool:
        """Push one beat if ready and no beat was accepted this cycle. Returns success."""
        if not self.ready or self._accepted_this_cycle:
            return False
        if self.kind == "axis":
            if not isinstance(beat, StreamBeat):
                raise TypeError("axis channel requires StreamBeat")
            nbytes = _axis_bytes(beat, self.data_width, self.keep_width)
        else:
            if not isinstance(beat, AvstBeat):
                raise TypeError("avst channel requires AvstBeat")
            nbytes = _avst_bytes(beat, self.data_width)
        self._slots.append(beat)
        self._accepted_this_cycle = True
        self.beats += 1
        self.bytes += nbytes
        return True

    def take(self) -> Beat | None:
        """Pop one beat for the consumer, or None if empty."""
        if not self._slots:
            return None
        return self._slots.popleft()
