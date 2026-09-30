# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0

"""Behavioral model of src/memory/fifo.sv as an AVST beat buffer.

Satisfies REQ-FIFO-001 .. REQ-FIFO-010 at the stream-abstraction level:
depth ``g_NUM_WORDS``, ``ready`` low when full, order preserved, one beat per cycle.
"""

from __future__ import annotations

from kernel.block import Block
from kernel.channel import Channel


class fifo(Block):
    """Single-clock FIFO of Avalon-ST beats (equal input/output width).

    ``snk`` and ``src`` share one Channel of depth ``g_NUM_WORDS``. System links
    push and pop that buffer; ``ready`` is false when it is full.
    """

    def __init__(
        self,
        name: str,
        g_NUM_WORDS: int = 4,
        g_INPUT_WIDTH: int = 8,
        g_OUTPUT_WIDTH: int | None = None,
        g_ENABLE_FWFT: bool = False,
    ) -> None:
        super().__init__(name)
        if g_OUTPUT_WIDTH is None:
            g_OUTPUT_WIDTH = g_INPUT_WIDTH
        if g_INPUT_WIDTH != g_OUTPUT_WIDTH:
            raise ValueError(
                "fifo model requires g_INPUT_WIDTH == g_OUTPUT_WIDTH "
                f"(got {g_INPUT_WIDTH} vs {g_OUTPUT_WIDTH})"
            )
        if g_NUM_WORDS < 1:
            raise ValueError("g_NUM_WORDS must be >= 1")
        self.g_NUM_WORDS = g_NUM_WORDS
        self.g_INPUT_WIDTH = g_INPUT_WIDTH
        self.g_OUTPUT_WIDTH = g_OUTPUT_WIDTH
        self.g_ENABLE_FWFT = g_ENABLE_FWFT
        self._mem = Channel("avst", data_width=g_INPUT_WIDTH, depth=g_NUM_WORDS)

    def ports(self) -> dict[str, Channel]:
        return {"snk": self._mem, "src": self._mem}

    def step(self) -> None:
        # Elastic store is the shared channel; System.connect transfers push/pop it.
        return
