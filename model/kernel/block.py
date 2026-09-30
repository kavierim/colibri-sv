# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary kernel shared by colibri_sv/model and PoC_sv/model. Behavioral models use each repo license.

"""Behavioral block base class."""

from __future__ import annotations

from kernel.channel import Channel


class Block:
    """Named model block with named Channel ports."""

    def __init__(self, name: str) -> None:
        self.name = name

    def ports(self) -> dict[str, Channel]:
        return {}

    def step(self) -> None:
        """Advance one cycle of block behavior. Default: no-op."""
