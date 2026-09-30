# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary kernel shared by colibri_sv/model and PoC_sv/model. Behavioral models use each repo license.

"""Beat payloads for AXI-Stream and Avalon-ST."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(slots=True)
class StreamBeat:
    """One AXI-Stream beat (valid/ready live on the Channel)."""

    tdata: int
    tkeep: int
    tlast: bool
    tid: int = 0
    tdest: int = 0
    tuser: int = 0


@dataclass(slots=True)
class AvstBeat:
    """One Avalon-ST beat."""

    data: int
    empty: int
    sop: bool
    eop: bool
