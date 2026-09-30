# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: Apache-2.0
# Ancillary kernel shared by colibri_sv/model and PoC_sv/model. Behavioral models use each repo license.

"""Compose blocks, connect channels, and run cycle simulation."""

from __future__ import annotations

from dataclasses import dataclass

from kernel.block import Block
from kernel.channel import Channel


class ConnectError(Exception):
    """Raised when two ports cannot be connected."""


@dataclass(slots=True)
class ChannelReport:
    beats: int
    bytes: int
    cycles: int
    bytes_per_cycle: float
    bits_per_sec: float | None


class Report:
    """Per-channel counters after a System.run()."""

    def __init__(self, channels: dict[str, ChannelReport]) -> None:
        self.channels = channels
        # Flat views keyed like "block.port" for convenient asserts.
        self.beats = {k: v.beats for k, v in channels.items()}
        self.bytes = {k: v.bytes for k, v in channels.items()}
        self.cycles = {k: v.cycles for k, v in channels.items()}
        self.bytes_per_cycle = {k: v.bytes_per_cycle for k, v in channels.items()}
        self.bits_per_sec = {k: v.bits_per_sec for k, v in channels.items()}


@dataclass(slots=True)
class _Link:
    src_block: Block
    src_port: str
    dst_block: Block
    dst_port: str


_WIDTH_FIELDS = ("data_width", "keep_width", "id_width", "dest_width", "user_width")


class System:
    """Collection of blocks and point-to-point channel connections."""

    def __init__(self) -> None:
        self._blocks: list[Block] = []
        self._links: list[_Link] = []

    def add(self, block: Block) -> None:
        self._blocks.append(block)

    def connect(
        self,
        src_block: Block,
        src_port: str,
        dst_block: Block,
        dst_port: str,
    ) -> None:
        src = self._port(src_block, src_port)
        dst = self._port(dst_block, dst_port)
        if src.kind != dst.kind:
            raise ConnectError(
                f"kind mismatch: {src_block.name}.{src_port} ({src.kind}) vs "
                f"{dst_block.name}.{dst_port} ({dst.kind})"
            )
        for field in _WIDTH_FIELDS:
            if getattr(src, field) != getattr(dst, field):
                raise ConnectError(
                    f"{field} mismatch: {src_block.name}.{src_port}="
                    f"{getattr(src, field)!r} vs {dst_block.name}.{dst_port}="
                    f"{getattr(dst, field)!r}"
                )
        self._links.append(_Link(src_block, src_port, dst_block, dst_port))

    def run(self, cycles: int) -> Report:
        for _ in range(cycles):
            for block in self._blocks:
                block.step()
            for link in self._links:
                src = self._port(link.src_block, link.src_port)
                dst = self._port(link.dst_block, link.dst_port)
                if not src._slots or not dst.ready or dst._accepted_this_cycle:
                    continue
                beat = src.take()
                if beat is None:
                    continue
                if not dst.accept(beat):
                    # Should not happen after ready check; restore to avoid loss.
                    src._slots.appendleft(beat)
            for channel in self._all_channels():
                channel.tick()
        return self._report()

    def _port(self, block: Block, name: str) -> Channel:
        ports = block.ports()
        if name not in ports:
            raise KeyError(f"block {block.name!r} has no port {name!r}")
        return ports[name]

    def _all_channels(self) -> list[Channel]:
        seen: set[int] = set()
        out: list[Channel] = []
        for block in self._blocks:
            for ch in block.ports().values():
                ident = id(ch)
                if ident not in seen:
                    seen.add(ident)
                    out.append(ch)
        return out

    def _report(self) -> Report:
        channels: dict[str, ChannelReport] = {}
        for block in self._blocks:
            for port_name, ch in block.ports().items():
                key = f"{block.name}.{port_name}"
                bpc = (ch.bytes / ch.cycles) if ch.cycles else 0.0
                channels[key] = ChannelReport(
                    beats=ch.beats,
                    bytes=ch.bytes,
                    cycles=ch.cycles,
                    bytes_per_cycle=bpc,
                    bits_per_sec=ch.bits_per_sec,
                )
        return Report(channels)
