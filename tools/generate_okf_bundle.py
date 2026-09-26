#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 CERN
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
# SPDX-License-Identifier: CERN-OHL-W-2.0
"""Generate the documentation bundle under docs/."""

from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
SRC = ROOT / "src"
GENERATED_AT = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
GENERATED_BY = "process:generate_doc_bundle/1.0"

UPSTREAM = (
    "https://gitlab.com/colibri-cern/colibri/-/tree/"
    "3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f"
)


def conventions_href(from_file: Path) -> str:
    depth = len(from_file.parent.relative_to(ROOT).parts)
    return f"{'../' * depth}CONVENTIONS.md"


def repo_href(from_file: Path, rel_to_root: str) -> str:
    depth = len(from_file.parent.relative_to(ROOT).parts)
    return f"{'../' * depth}{rel_to_root.removeprefix('/')}"


def doc_href(from_file: Path, under_docs: str) -> str:
    """Relative link from a markdown file to another path under docs/."""
    dest = (DOCS / under_docs.removeprefix("/")).resolve()
    return Path(os.path.relpath(dest, from_file.parent.resolve())).as_posix()


def expand_doc_links(text: str, from_file: Path) -> str:
    """Turn docs-root links (/foo.md) into GitHub-friendly relative links."""

    def repl(match: re.Match[str]) -> str:
        return f"]({doc_href(from_file, match.group(1))})"

    return re.sub(r"\]\(/([^)]+)\)", repl, text)


# module_name -> (docs_domain_path, rtl_path relative to repo root)
MODULE_DOMAIN: dict[str, tuple[str, str]] = {}
DESCRIPTIONS: dict[str, str] = {}
VERIFICATION: dict[str, dict[str, str]] = {}

DOMAIN_META = {
    "common": ("domain:common", "src/common/readme.md", "verilator/files/common.f"),
    "memory": ("domain:memory", "src/memory/readme.md", "verilator/files/memory.f"),
    "comms": ("domain:comms", "src/comms/readme.md", "verilator/files/comms.f"),
    "endec": ("domain:endec", "src/endec/readme.md", "verilator/files/endec.f"),
    "io": ("domain:io", "src/io/readme.md", "verilator/files/io.f"),
    "interfaces": (
        "domain:interfaces",
        "src/interfaces/readme.md",
        "verilator/files/interfaces.f",
    ),
    "packet": ("domain:packet", "src/packet/readme.md", "verilator/files/packet_pipes.f"),
    "pipes": ("domain:pipes", "src/pipes/readme.md", "verilator/files/packet_pipes.f"),
    "misc": ("domain:misc", "src/misc/readme.md", "verilator/files/misc.f"),
    "proto/aurora_64b66b": (
        "domain:aurora",
        "src/proto/aurora_64b66b/readme.md",
        "verilator/files/aurora.f",
    ),
}

PACKAGES = {
    "colibri_utils": ("src/common/utils.sv", "Bit-math, registers, and byte manipulation."),
    "colibri_types": (
        "src/common/types.sv",
        "Avalon-ST and AXI-Stream types and conversion helpers.",
    ),
    "colibri_encoders": ("src/common/encoders.sv", "Gray, one-hot, and related encodings."),
    "colibri_poly": ("src/common/poly_pkg.sv", "CRC, scrambler, and PRBS polynomials."),
    "colibri_mem": ("src/memory/mem_pkg.sv", "Shared memory helpers."),
    "colibri_common_8b10b": (
        "src/endec/common_8b10b_pkg.sv",
        "8b/10b encode and decode lookup tables.",
    ),
    "colibri_binaryio": (
        "src/fileio/binaryio.sv",
        "Simulation binary file read and write tasks.",
    ),
    "colibri_aurora_const": (
        "src/proto/aurora_64b66b/include/aurora_const_pkg.sv",
        "Aurora 64b/66b protocol constants.",
    ),
    "reg_utils": (
        "src/misc/mmap_fifo/vhdl_if/reg_utils.sv",
        "CSR field read/write helpers.",
    ),
    "mmap_fifo_csr_pkg": (
        "src/misc/mmap_fifo/vhdl_if/mmap_fifo_csr_pkg.sv",
        "Top-level mmap FIFO register definitions.",
    ),
    "txfifo_csr_pkg": (
        "src/misc/mmap_fifo/vhdl_if/txfifo_csr_pkg.sv",
        "TX FIFO CSR definitions.",
    ),
    "rxfifo_csr_pkg": (
        "src/misc/mmap_fifo/vhdl_if/rxfifo_csr_pkg.sv",
        "RX FIFO CSR definitions.",
    ),
}

WHEN_TO_USE: dict[str, str] = {
    "skid_buffer": "Prefer [`stream_buffer`](/modules/common/stream_buffer.md) with `g_REGISTER_DATAPATH = 0`.",
    "pipeline_buffer": "Prefer [`stream_buffer`](/modules/common/stream_buffer.md) with `g_REGISTER_DATAPATH = 1`.",
    "cc_fifo": "For asymmetric widths at lower LUT cost, compare [`cc_ram_fifo`](/modules/memory/cc_ram_fifo.md).",
    "cc_ram_fifo": "Use [`cc_fifo`](/modules/memory/cc_fifo.md) when a logic FIFO is sufficient or widths match.",
    "packet_cc_fifo": "Legacy style; consider [`packet_cc_ram_fifo`](/modules/memory/packet_cc_ram_fifo.md) for RAM-backed CDC packet storage.",
    "gearbox": "Use [`cc_gearbox`](/modules/comms/cc_gearbox.md) when the two sides use different clocks.",
    "cc_gearbox": "Use [`gearbox`](/modules/comms/gearbox.md) for single-clock width conversion.",
    "simple_dpram_xilinx": "Simulation and default [`simple_dpram`](/modules/memory/simple_dpram.md); force Xilinx BRAM inference in synthesis.",
    "simple_dpram_altera": "Force Intel/Altera BRAM inference; otherwise use `simple_dpram`.",
    "true_dpram_xilinx": "Vendor Xilinx variant of [`true_dpram`](/modules/memory/true_dpram.md).",
    "true_dpram_altera": "Vendor Altera variant of `true_dpram`.",
    "uart_tx": "Use [`uart`](/modules/io/uart.md) for a combined transceiver.",
    "uart_rx": "Use `uart` for a combined transceiver.",
    "mmap_fifo_tx": "Full bridge: [`mmap_fifo`](/modules/misc/mmap_fifo.md).",
    "mmap_fifo_rx": "Full bridge: `mmap_fifo`.",
    "gearbox_up": "Aurora RX upscaler; not [`comms/gearbox`](/modules/comms/gearbox.md).",
    "cc_gearbox_up": "Clock-crossing Aurora upscaler variant in the RX path.",
    "avst_to_axis": "Place after AVST packet logic; pair with [`axis_to_avst`](/modules/interfaces/axis_to_avst.md) for round-trip. See [stream-interfaces](/playbooks/stream-interfaces.md).",
    "axis_to_avst": "Ingress from AXI-Stream IP; often follows [`avst_to_axis`](/modules/interfaces/avst_to_axis.md) in the reverse direction.",
    "avst_width_converter": "Between AVST blocks with different beat widths; keep `g_SYM_WIDTH` consistent. Needs packet `sop`/`eop`/`empty` preserved.",
    "avst_cdc": "For AVST packet streams across clocks; arbitrary payloads may use [`synchro_handshake`](/modules/common/synchro_handshake.md) instead.",
    "avst_fifo": "Thin wrapper around [`packet_fifo`](/modules/memory/packet_fifo.md) or width-matched FIFO—check generics against your beat width.",
    "crc": "Append or check CRC on an AVST packet stream; polynomial from [`colibri_poly`](/packages/colibri_poly.md).",
    "scrambler": "Line coding before PHY; pair with [`descrambler`](/modules/comms/descrambler.md). Polynomial via `colibri_poly`.",
    "packet_fifo": "Single-clock AVST packet FIFO; dual-clock CDC: [`packet_cc_ram_fifo`](/modules/memory/packet_cc_ram_fifo.md).",
    "mmap_fifo": "CPU access to AVST TX/RX packet FIFOs over Wishbone; see CSR packages under `docs/packages/`.",
    "counter": "Basic timed/event counting; set `g_MODULO` and width explicitly for wrap behaviour.",
    "comparator": "Registered compare with enable; unsigned `a_i`/`b_i`; use `g_IS_EQUAL` for `>=` instead of `>`.",
}

STABLE_MODULES = frozenset(
    {
        "counter",
        "comparator",
        "stream_buffer",
        "fifo",
        "packet_fifo",
        "cc_fifo",
        "avst_to_axis",
        "axis_to_avst",
        "avst_width_converter",
        "avst_cdc",
        "crc",
        "scrambler",
        "mmap_fifo",
    }
)

STABLE_PACKAGES = frozenset({"colibri_utils", "colibri_types"})

DOMAIN_BEHAVIOUR: dict[str, str] = {
    "common": "See RTL for clocking; not every block has `reset_i`.",
    "memory": "FIFOs support optional first-word fall-through via `g_ENABLE_FWFT`. Packet FIFOs honour Avalon-ST `startofpacket`/`endofpacket`.",
    "comms": "Stream-facing modules use Avalon-ST records from `colibri_types` unless the RTL exposes a simple valid/ready bus.",
    "endec": "8b/10b tables live in `colibri_common_8b10b`; RLE modules operate on streaming data.",
    "io": "Pin-level protocols; see area readme for Verilator modelling notes (e.g. I2C SCL release).",
    "interfaces": "Stream adapters assume `colibri_types` AVST/AXIS macros. See [stream-interfaces](/playbooks/stream-interfaces.md).",
    "packet": "Packet semantics follow Avalon-ST: `startofpacket`, `endofpacket`, and `empty` on beats.",
    "pipes": "Round-robin grants one input stream per cycle when the sink accepts a beat.",
    "misc": "Many blocks are Avalon-ST packet manipulators or Wishbone bridges.",
    "proto/aurora_64b66b": "Line-rate gearboxes may not propagate `ready` on the optimized RX path; size `g_GBX_BUF_SIZE` for backpressure in simulation.",
}


# Frozen catalog (source of truth after COMPONENTS.md was slimmed).
CATALOG: dict[str, str] = {
    "counter": "Simple counter with optional modulo and enable.",
    "comparator": "Comparator with enable.",
    "debouncer": "Input debouncer.",
    "edge_detect": "Rising and falling edge detection.",
    "synchro": "Clock-domain crossing for a packed vector.",
    "synchro_generic": "CDC for a user-defined payload type.",
    "synchro_reset": "Reset synchronizer.",
    "synchro_pulse": "Pulse synchronizer across clock domains.",
    "synchro_handshake": "Stream CDC with backpressure propagation.",
    "stream_buffer": "Elastic stream buffer (skid or pipeline via generic).",
    "stream_buffer_generic": "Same buffer with a parameterized data type.",
    "skid_buffer": "Legacy low-latency elastic buffer; prefer `stream_buffer`.",
    "pipeline_buffer": "Legacy two-stage decoupled buffer; prefer `stream_buffer`.",
    "fifo": "Single-clock FIFO; arbitrary input and output width.",
    "cc_fifo": "Dual-clock asynchronous FIFO; arbitrary widths.",
    "cc_ram_fifo": "Dual-clock RAM-based FIFO with asymmetric ports.",
    "packet_fifo": "Single-clock Avalon-ST packet FIFO.",
    "packet_cc_fifo": "Dual-clock Avalon-ST packet FIFO (legacy style).",
    "packet_cc_ram_fifo": "Dual-clock packet FIFO with RAM and mixed widths.",
    "bicam": "Binary content-addressable memory.",
    "rom": "Read-only memory loaded from a hex init file.",
    "ram": "Single-port, single-clock RAM.",
    "simple_dpram": "Simple dual-port RAM (one write, one read); dual clock.",
    "simple_dpram_be": "`simple_dpram` with byte-enable on the write port.",
    "true_dpram": "True dual-port RAM (two write and two read ports).",
    "ring_buffer": "Circular buffer; overwrite oldest when full.",
    "simple_dpram_xilinx": "Vendor-style simple DPRAM for Xilinx BRAM inference.",
    "simple_dpram_altera": "Vendor-style simple DPRAM for Intel/Altera inference.",
    "true_dpram_xilinx": "Vendor-style true DPRAM for Xilinx.",
    "true_dpram_altera": "Vendor-style true DPRAM for Intel/Altera.",
    "scrambler": "Self-synchronous (multiplicative) scrambler.",
    "descrambler": "Matching descrambler.",
    "slip_buffer": "Slip buffer for stream bit alignment.",
    "gearbox": "Single-clock width gearbox.",
    "cc_gearbox": "Dual-clock width gearbox.",
    "crc": "CRC over an Avalon-ST packet stream.",
    "bert": "PRBS bit-error-rate tester.",
    "bit_shifter": "Arbitrary bit shift on a stream.",
    "rle_encode": "Run-length encoder.",
    "rle_decode": "Run-length decoder.",
    "encode_8b10b": "8b/10b encoder.",
    "decode_8b10b": "8b/10b decoder.",
    "uart": "UART transceiver (TX + RX).",
    "uart_tx": "UART transmitter only.",
    "uart_rx": "UART receiver only.",
    "spi_master": "SPI master.",
    "spi_slave": "SPI slave.",
    "i2c_controller": "I2C master controller.",
    "jtag_serdes": "JTAG USER-register duplex stream bridge.",
    "avst_cdc": "Avalon-ST clock-domain crossing.",
    "avst_fifo": "Avalon-ST FIFO wrapper.",
    "avst_to_axis": "Avalon-ST to AXI-Stream adapter.",
    "axis_to_avst": "AXI-Stream to Avalon-ST adapter.",
    "avst_width_converter": "Avalon-ST data-width converter.",
    "avst_ram_write": "Write Avalon-ST beats into RAM.",
    "avst_ram_write_unaligned": "Byte-addressable Avalon-ST RAM writer.",
    "avst_ram_read": "Read Avalon-ST beats from RAM.",
    "avst_ram_read_unaligned": "Byte-addressable Avalon-ST RAM reader.",
    "wb_ram": "RAM with Wishbone B4 slave port.",
    "header_add": "Prepend a fixed header to each packet.",
    "header_remove": "Strip a fixed header from each packet.",
    "interleaver": "Merge multiple packet streams into one.",
    "deinterleaver": "Split one stream into multiple outputs.",
    "broadcaster": "Duplicate one stream to several outputs.",
    "packet_join": "Concatenate consecutive packets into one.",
    "packet_delay": "Delay packets by a fixed number of clocks.",
    "arbiter": "Round-robin arbiter for multiple stream sources.",
    "be_add_lead": "Insert a leading word on an Avalon-ST packet.",
    "be_add_trail": "Append a trailing word (e.g. CRC).",
    "be_remove_lead": "Remove the leading word (e.g. header).",
    "be_remove_trail": "Remove the trailing word (e.g. CRC).",
    "mmap_fifo": "Wishbone slave to full-duplex Avalon-ST packet FIFO.",
    "mmap_fifo_tx": "TX half of `mmap_fifo`.",
    "mmap_fifo_rx": "RX half of `mmap_fifo`.",
    "mmap_fifo_csr": "Top CSR block for mmap FIFO.",
    "txfifo_csr": "TX FIFO CSR block.",
    "rxfifo_csr": "RX FIFO CSR block.",
    "heartbeat": "Periodic heartbeat from a divided counter.",
    "powerup_reset": "Power-up reset stretcher.",
    "stream_to_wbm": "Bidirectional stream to Wishbone B4 master.",
    "frequency_counter": "Measure an input clock against a reference.",
    "aurora_tx": "Aurora transmitter (64b stream to encoded lanes).",
    "aurora_rx": "Aurora receiver (lanes to 64b stream).",
    "aurora_st_encoder": "Aurora stream encoder block.",
    "aurora_st_decoder": "Aurora stream decoder block.",
    "gearbox_up": "Continuous upscaling gearbox (RX path).",
    "cc_gearbox_up": "Clock-crossing upscaling gearbox variant.",
    "block_sync_fsm": "Block synchronization state machine.",
    "channel_bond": "Multi-lane channel bonding.",
    "meta_buffer": "Metadata buffer in the RX datapath.",
}


def parse_components() -> None:
    DESCRIPTIONS.update(CATALOG)


def assign_module_paths() -> None:
    for sv in SRC.rglob("*.sv"):
        content = sv.read_text(encoding="utf-8", errors="replace")
        mm = re.search(r"^\s*module\s+(\w+)\s*[#(]", content, re.M)
        if not mm:
            continue
        name = mm.group(1)
        rel = sv.relative_to(ROOT).as_posix()
        if name in DESCRIPTIONS:
            dom = None
            for d in sorted(DOMAIN_META.keys(), key=len, reverse=True):
                prefix = f"src/{d}/"
                if rel.startswith(prefix) or rel == f"src/{d}.sv":
                    dom = d
                    break
            if dom is None:
                if rel.startswith("src/common/"):
                    dom = "common"
                elif rel.startswith("src/memory/"):
                    dom = "memory"
                elif rel.startswith("src/comms/"):
                    dom = "comms"
                elif rel.startswith("src/endec/"):
                    dom = "endec"
                elif rel.startswith("src/io/"):
                    dom = "io"
                elif rel.startswith("src/interfaces/"):
                    dom = "interfaces"
                elif rel.startswith("src/packet/"):
                    dom = "packet"
                elif rel.startswith("src/pipes/"):
                    dom = "pipes"
                elif rel.startswith("src/misc/"):
                    dom = "misc"
                elif rel.startswith("src/proto/aurora_64b66b/"):
                    dom = "proto/aurora_64b66b"
                else:
                    dom = "misc"
            MODULE_DOMAIN[name] = (dom, rel)


# Verification rows migrated from area readmes (readmes are slim pointers to docs/).
VERIFICATION_CATALOG: dict[str, tuple[str, str, str]] = {
    "colibri_utils": ("yes", "sim/common/utils_tb.sv", "fv/common/utils_sva.sv"),
    "colibri_encoders": ("yes", "sim/common/encoders_tb.sv", ""),
    "colibri_types": ("yes", "sim/common/type_conv_tb.sv", ""),
    "counter": ("yes", "sim/common/counter_tb.sv", "fv/common/counter_sva.sv"),
    "comparator": ("yes", "sim/common/comparator_tb.sv", ""),
    "edge_detect": ("yes", "sim/common/edge_detect_tb.sv", "fv/common/edge_detect_sva.sv"),
    "synchro": ("yes", "sim/common/synchro_tb.sv", ""),
    "synchro_generic": ("yes", "sim/common/synchro_generic_tb.sv", ""),
    "synchro_reset": ("yes", "sim/common/synchro_reset_tb.sv", ""),
    "synchro_pulse": ("yes", "sim/common/synchro_pulse_tb.sv", ""),
    "synchro_handshake": ("yes", "sim/common/synchro_handshake_tb.sv", ""),
    "stream_buffer": ("yes", "sim/common/stream_buffer_tb.sv", "fv/common/stream_buffer_sva.sv"),
    "stream_buffer_generic": ("yes", "sim/common/stream_buffer_generic_tb.sv", ""),
    "debouncer": ("yes", "sim/common/debouncer_tb.sv", "fv/common/debouncer_sva.sv"),
    "skid_buffer": ("yes", "sim/common/skid_buffer_tb.sv", "fv/common/skid_buffer_sva.sv"),
    "pipeline_buffer": ("yes", "sim/common/pipeline_buffer_tb.sv", "fv/common/pipeline_buffer_sva.sv"),
    "fifo": ("yes", "sim/memory/fifo_tb.sv, fifo_fwft_tb.sv, mixedw_fifo_tb.sv, mixedw_fifo_fwft_tb.sv", "fv/memory/fifo_sva.sv (bound on fifo_tb)"),
    "cc_fifo": ("yes", "sim/memory/cc_fifo_tb.sv, mixedw_cc_fifo_tb.sv, mixedw_cc_fifo_fwft_tb.sv", ""),
    "cc_ram_fifo": ("yes", "sim/memory/cc_ram_fifo_tb.sv", ""),
    "packet_fifo": ("yes", "sim/memory/packet_fifo/packet_fifo_tb.sv", ""),
    "packet_cc_fifo": ("yes", "sim/memory/packet_cc_fifo/packet_cc_fifo_tb.sv", ""),
    "packet_cc_ram_fifo": ("yes", "sim/memory/packet_cc_ram_fifo/packet_cc_ram_fifo_tb.sv", ""),
    "bicam": ("yes", "sim/memory/bicam_tb.sv", ""),
    "rom": ("yes", "sim/memory/rom/rom_tb.sv", ""),
    "ram": ("yes", "sim/memory/ram_tb.sv", ""),
    "simple_dpram": ("yes", "sim/memory/simple_dpram_tb.sv", ""),
    "simple_dpram_be": ("yes", "sim/memory/simple_dpram_be_tb.sv", ""),
    "true_dpram": ("yes", "sim/memory/true_dpram_tb.sv", ""),
    "ring_buffer": ("yes", "sim/memory/ring_buffer_tb.sv", "fv/memory/ring_buffer_sva.sv"),
    "scrambler": ("yes", "sim/comms/scrambler_tb.sv", ""),
    "descrambler": ("yes", "covered by scrambler_tb and prbs_tb", ""),
    "slip_buffer": ("yes", "sim/comms/slip_buffer_tb.sv", ""),
    "cc_gearbox": ("yes", "sim/comms/cc_gearbox_up_tb.sv, cc_gearbox_down_tb.sv, cc_gearbox_*_thr_tb.sv, cc_gearbox_loopback_tb.sv", ""),
    "gearbox": ("yes", "sim/comms/gearbox_up_tb.sv, gearbox_down_tb.sv, gearbox_loopback_tb.sv", "fv/comms/gearbox_up_sva.sv, gearbox_down_sva.sv"),
    "crc": ("yes", "sim/comms/crc_tb.sv", ""),
    "bert": ("yes", "sim/comms/bert_tb.sv", ""),
    "bit_shifter": ("yes", "sim/comms/bit_shifter_tb.sv", ""),
    "rle_encode": ("yes", "sim/endec/rle_encode_tb.sv", "fv/endec/rle_encode_sva.sv"),
    "rle_decode": ("yes", "sim/endec/rle_decode_tb.sv", "fv/endec/rle_decode_sva.sv"),
    "encode_8b10b": ("yes", "sim/endec/loopback_8b10b_tb.sv", ""),
    "decode_8b10b": ("yes", "sim/endec/decode_8b10b_tb.sv, loopback_8b10b_tb.sv", ""),
    "i2c_controller": ("yes", "sim/io/i2c/i2c_controller_tb.sv", ""),
    "uart": ("yes", "sim/io/uart/uart_tb.sv", ""),
    "spi_slave": ("yes", "sim/io/spi/spi_slave_tb.sv", ""),
    "spi_master": ("yes", "sim/io/spi/spi_master_tb.sv", ""),
    "jtag_serdes": ("yes", "sim/io/jtag/jtag_serdes_tb.sv", ""),
    "avst_cdc": ("yes", "sim/interfaces/stream/avst_cdc_tb.sv", ""),
    "avst_fifo": ("yes", "sim/interfaces/stream/avst_fifo_tb.sv", ""),
    "avst_to_axis": ("yes", "sim/interfaces/stream/avst_to_axis_tb.sv", "fv/interfaces/stream/avst_to_axis_sva.sv"),
    "avst_width_converter": ("yes", "sim/interfaces/stream/avst_width_converter_tb.sv", ""),
    "axis_to_avst": ("yes", "sim/interfaces/stream/axis_to_avst_tb.sv", "fv/interfaces/stream/axis_to_avst_sva.sv"),
    "avst_ram_write": ("yes", "sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv", "fv/interfaces/stream/avst_ram_write_sva.sv"),
    "avst_ram_read": ("yes", "sim/interfaces/stream/avst_ram_tb/avst_ram_tb.sv", "fv/interfaces/stream/avst_ram_read_sva.sv"),
    "avst_ram_write_unaligned": ("yes", "sim/interfaces/stream/avst_ram_write_unaligned_tb.sv, avst_ram_be_tb/", "fv/interfaces/stream/avst_ram_write_unaligned_sva.sv"),
    "avst_ram_read_unaligned": ("yes", "sim/interfaces/stream/avst_ram_read_unaligned_tb/, avst_ram_be_tb/", ""),
    "wb_ram": ("yes", "sim/interfaces/memory_mapped/wb_ram_tb.sv", ""),
    "header_remove": ("yes", "sim/packet/header_remove_tb.sv", "fv/packet/header_remove_sva.sv"),
    "header_add": ("yes", "sim/packet/header_add_tb.sv", "fv/packet/header_add_sva.sv"),
    "interleaver": ("yes", "sim/packet/interleaver_tb.sv", "fv/packet/interleaver_sva.sv, interleaver_bd_sva.sv"),
    "deinterleaver": ("yes", "sim/packet/interleaver_loopback_tb.sv", "fv/packet/deinterleaver_sva.sv"),
    "broadcaster": ("yes", "sim/packet/broadcaster_tb.sv", "fv/packet/broadcaster_sva.sv"),
    "packet_join": ("yes", "sim/packet/packet_join_tb.sv", "fv/packet/packet_join_sva.sv"),
    "packet_delay": ("yes", "sim/packet/packet_delay_tb.sv", "fv/packet/packet_delay_sva.sv"),
    "arbiter": ("yes", "sim/pipes/arbiter_tb.sv", "fv/pipes/arbiter_sva.sv"),
    "be_add_lead": ("yes", "sim/misc/be_add_lead_tb.sv", "fv/misc/be_add_lead_sva.sv"),
    "be_add_trail": ("yes", "sim/misc/be_add_trail_tb.sv", "fv/misc/be_add_trail_sva.sv"),
    "be_remove_lead": ("yes", "sim/misc/be_remove_lead_tb.sv", "fv/misc/be_remove_lead_sva.sv"),
    "be_remove_trail": ("yes", "sim/misc/be_remove_trail_tb.sv", "fv/misc/be_remove_trail_sva.sv"),
    "mmap_fifo_tx": ("yes", "sim/misc/mmap_fifo/mmap_fifo_tb.sv", ""),
    "mmap_fifo_rx": ("yes", "sim/misc/mmap_fifo/mmap_fifo_tb.sv", ""),
    "mmap_fifo": ("yes", "sim/misc/mmap_fifo/mmap_fifo_tb.sv", ""),
    "heartbeat": ("yes", "sim/misc/heartbeat_tb.sv", ""),
    "powerup_reset": ("yes", "sim/misc/powerup_reset_tb.sv", ""),
    "stream_to_wbm": ("yes", "sim/misc/stream_to_wbm_tb.sv", ""),
    "frequency_counter": ("yes", "sim/misc/frequency_counter_tb.sv", ""),
    "colibri_binaryio": ("yes", "sim/fileio/binaryio_tb.sv", ""),
}


def parse_verification_tables() -> None:
    for name, (sim, tb, sva) in VERIFICATION_CATALOG.items():
        VERIFICATION[name] = {"simulation": sim, "testbench": tb, "sva": sva}
    for readme in SRC.rglob("readme.md"):
        text = readme.read_text(encoding="utf-8")
        if "Development status and testing" not in text and "### Tests" not in text:
            continue
        lines = text.splitlines()
        in_table = False
        for line in lines:
            if line.strip().startswith("| Module") or line.strip().startswith("| Package"):
                in_table = True
                continue
            if in_table:
                if not line.strip().startswith("|"):
                    if line.strip() == "":
                        continue
                    in_table = False
                    continue
                if re.match(r"\| ---", line):
                    continue
                parts = [p.strip().strip("`") for p in line.split("|")[1:-1]]
                if len(parts) >= 4:
                    mod, sim, tb, sva = parts[0], parts[1], parts[2], parts[3]
                    VERIFICATION[mod] = {
                        "simulation": sim,
                        "testbench": tb,
                        "sva": sva if sva.lower() not in ("no", "none") else "",
                    }
    # aurora tests table uses different columns
    aurora = (SRC / "proto/aurora_64b66b/readme.md").read_text(encoding="utf-8")
    for line in aurora.splitlines():
        m = re.match(r"\| `([^`]+)` \| (.+) \|", line)
        if m:
            VERIFICATION.setdefault(
                Path(m.group(1)).stem.replace("_tb", ""),
                {"simulation": "yes", "testbench": m.group(1), "sva": ""},
            )


def extract_header_comments(sv_path: Path) -> str:
    lines = []
    for line in sv_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("//") and not line.startswith("// SPDX"):
            t = line[2:].strip()
            if t and not t.startswith("Modified:") and not t.startswith("Translated"):
                if t.startswith("Upstream:"):
                    continue
                if t.startswith("Entity files") or t.startswith("verilator"):
                    continue
                lines.append(t)
        elif line.strip().startswith("module "):
            break
    return " ".join(lines[:12]).strip()


def parse_module_interface(sv_path: Path) -> tuple[list[str], list[str]]:
    text = sv_path.read_text(encoding="utf-8")
    m = re.search(
        r"module\s+\w+\s*#\s*\((.*?)\)\s*\((.*?)\)\s*;",
        text,
        re.DOTALL,
    )
    if m:
        param_blob, port_blob = m.group(1), m.group(2)
    else:
        m2 = re.search(r"module\s+\w+\s*\((.*?)\)\s*;", text, re.DOTALL)
        if not m2:
            return [], []
        param_blob, port_blob = "", m2.group(1)

    def split_declarations(blob: str, kind: str) -> list[str]:
        out: list[str] = []
        for raw in blob.splitlines():
            line = raw.strip()
            if not line or line.startswith("//"):
                continue
            line = line.rstrip(",").strip()
            if kind == "param" and ("parameter" in line or re.match(r"type\s+\w+", line)):
                out.append(line)
            elif kind == "port" and line.split()[0] in ("input", "output", "inout"):
                out.append(line)
        return out

    return split_declarations(param_blob, "param"), split_declarations(port_blob, "port")


MODULE_ENRICHMENT: dict[str, dict[str, str]] = {
    "stream_buffer": {
        "when": (
            "Default elastic buffer for valid/ready streams. Set `g_REGISTER_DATAPATH = 0` for skid "
            "(minimum latency 0) or `1` for pipeline (minimum latency 1). "
            "Prefer over legacy [`skid_buffer`](/modules/common/skid_buffer.md) and "
            "[`pipeline_buffer`](/modules/common/pipeline_buffer.md)."
        ),
        "behaviour": (
            "Skid mode keeps the datapath direct in normal operation; on backpressure the in-flight beat "
            "is stored and `snk_ready_o` can deassert until the skid empties. Pipeline mode always "
            "registers data (two-word FIFO semantics) and fully decouples source and destination."
        ),
    },
    "fifo": {
        "behaviour": (
            "Optional first-word fall-through: with `g_ENABLE_FWFT` set, `rdreq` acts as acknowledge and "
            "`empty` means not-valid; otherwise `rdreq` is a read request with one-cycle data latency."
        ),
    },
    "jtag_serdes": {
        "when": (
            "Bridge parallel stream beats to a JTAG USER data register. Often paired with "
            "[`stream_to_wbm`](/modules/misc/stream_to_wbm.md) for register access over JTAG."
        ),
        "integration": (
            "Vendor BSCAN primitives are outside this port. Connect `shift_i`/`update_i` as "
            "`shift & sel` and `update & sel`. AMD USER1 IR is `0x02`; Intel USER0 is `0x00C`. "
            "See OpenOCD `irscan` / `drscan` examples in the upstream JTAG readme (now summarized here)."
        ),
        "examples": """```systemverilog
jtag_serdes #(
  .g_DATA_WIDTH(40)
) jtag_serdes_inst (
  .clk_ser_i   (gck),
  .clk_par_i   (sys_clk),
  .shift_i     (shift & sel),
  .update_i    (update & sel),
  .par_data_i  (ps_data),
  .par_valid_i (ps_valid),
  .par_ready_o (),
  .par_data_o  (sp_data),
  .par_valid_o (sp_valid),
  .ser_data_i  (tdi),
  .ser_data_o  (tdo)
);
```""",
    },
    "aurora_tx": {
        "behaviour": (
            "Top-level transmitter: 64-bit stream to Aurora-encoded lanes. Generics `g_N_LANES` and "
            "`g_LANE_WIDTH` set PHY width. Size `g_GBX_BUF_SIZE` for gearbox buffering under backpressure."
        ),
    },
    "aurora_rx": {
        "behaviour": (
            "Top-level receiver with optional optimized RX gearbox (`g_USE_OPTIMIZED_GBX` defaults to 1). "
            "The continuous gearbox assumes a streaming line with limited `ready` backpressure—validate "
            "buffer depth in simulation."
        ),
    },
    "block_sync_fsm": {
        "behaviour": (
            "Block synchronization FSM for Aurora RX. Tune `g_SH_INVALID_CNT_MAX` and `g_SH_CNT_MAX` when "
            "the link loses lock or corrupts framing."
        ),
    },
    "avst_width_converter": {
        "behaviour": (
            "Buffers and serialises beats when `g_INPUT_SYM` and `g_OUTPUT_SYM` differ. "
            "`snk_*` is the wide side, `src_*` the narrow side (or vice versa per parameterisation). "
            "Preserves packet boundaries via `sop`/`eop` and `empty`."
        ),
    },
    "avst_to_axis": {
        "when": (
            "Connect colibri AVST logic to AXI-Stream IP. Map `tkeep` from beat width; "
            "see [`colibri_types`](/packages/colibri_types.md)."
        ),
    },
    "crc": {
        "behaviour": (
            "Computes CRC over the AVST packet on the fly; configure polynomial width and init via generics. "
            "Typically sits before [`be_add_trail`](/modules/misc/be_add_trail.md) or after payload logic."
        ),
    },
    "scrambler": {
        "behaviour": (
            "Multiplicative self-synchronous scrambler on a bit or byte stream. "
            "Reset state must match the link partner; pair with `descrambler` on the receive path."
        ),
    },
    "mmap_fifo": {
        "when": (
            "Software-driven packet IO: Wishbone register file + TX/RX AVST packet ports. "
            "Split hierarchy: [`mmap_fifo_tx`](/modules/misc/mmap_fifo_tx.md), "
            "[`mmap_fifo_rx`](/modules/misc/mmap_fifo_rx.md), CSR blocks in `mmap_fifo/vhdl_if/`."
        ),
    },
}


def yaml_frontmatter(
    *,
    type_: str,
    title: str,
    description: str,
    tags: list[str],
    resource: str | None = None,
    status: str = "draft",
) -> str:
    lines = [
        "---",
        f"type: {type_}",
        f"title: {title}",
        f"description: {description}",
        f"tags: [{', '.join(tags)}]",
        f"generated: {{ by: {GENERATED_BY}, at: {GENERATED_AT} }}",
        f"status: {status}",
    ]
    if resource:
        lines.append(f"resource: {resource}")
    lines.append("sources:")
    lines.append("  - id: upstream")
    lines.append(f"    resource: {UPSTREAM}")
    lines.append("    title: Upstream VHDL at pin commit")
    lines.append("---")
    return "\n".join(lines)


def example_instantiation(name: str, ports: list[str], flist: str) -> str:
    port_names: list[str] = []
    for line in ports:
        m = re.search(r"(\w+)\s*$", line.strip().rstrip(","))
        if m:
            port_names.append(m.group(1))
    if port_names:
        conn = ",\n".join(f"  .{pn} (...)" for pn in port_names[:16])
        if len(port_names) > 16:
            conn += ",\n  // ..."
    else:
        conn = "  // connect ports from Schema"
    return f"""```systemverilog
// Compile {flist} and verilator/colibri.f

{name} #(
  // parameters from Schema
) u_{name} (
{conn}
);
```"""


def write_module_page(name: str, dom: str, rtl: str) -> Path:
    desc = DESCRIPTIONS.get(name, f"Colibri module `{name}`.")
    doc_path = DOCS / "modules" / dom / f"{name}.md"
    doc_path.parent.mkdir(parents=True, exist_ok=True)
    sv_path = ROOT / rtl
    comments = extract_header_comments(sv_path)
    params, ports = parse_module_interface(sv_path)
    tag_base = DOMAIN_META.get(dom, ("domain:unknown", "", ""))[0]
    tags = [tag_base, f"module:{name}"]
    if "stream" in rtl or "avst" in name or "axis" in name:
        tags.append("interface:avst")
    if "cdc" in name or "cc_" in name or name.startswith("synchro"):
        tags.append("cdc")

    enrich = MODULE_ENRICHMENT.get(name, {})
    when = enrich.get(
        "when",
        WHEN_TO_USE.get(
            name,
            f"See the [{dom.split('/')[-1]} domain index](/modules/{dom}/index.md) for siblings and typical compositions.",
        ),
    )
    behaviour = enrich.get(
        "behaviour",
        DOMAIN_BEHAVIOUR.get(dom, "See RTL and area readme for protocol details."),
    )
    if comments:
        behaviour = f"{comments} {behaviour}"

    ver = VERIFICATION.get(name, {})
    sim = ver.get("simulation", "see area index")
    tb = ver.get("testbench", "none listed")
    sva = ver.get("sva", "")

    flist = DOMAIN_META.get(dom, ("", "", "verilator/colibri.f"))[2]
    concept = f"/modules/{dom}/{name}.md"

    param_table = "| Declaration |\n| --- |\n"
    if params:
        for p in params[:40]:
            param_table += f"| `{p}` |\n"
    else:
        param_table += "| (none) |\n"

    port_table = "| Declaration |\n| --- |\n"
    if ports:
        for p in ports[:60]:
            port_table += f"| `{p}` |\n"
    else:
        port_table += "| (see RTL) |\n"

    imports = ""
    if "avst" in rtl or dom in ("interfaces", "packet", "misc", "memory"):
        imports = "\nImport [`colibri_types`](/packages/colibri_types.md) when the ports use AVST/AXIS structs.\n"

    if "examples" in enrich:
        example = enrich["examples"]
    else:
        example = example_instantiation(name, ports, flist)

    conv = conventions_href(doc_path)
    related = []
    if dom == "common":
        related.append("[common domain](/modules/common/index.md)")
    related.append(f"[{dom} RTL]({repo_href(doc_path, rtl)})")
    related.append("[simulation](/playbooks/simulation.md)")

    types_blurb = (
        f"Key types and width rules: [`CONVENTIONS.md`]({conv}) and "
        f"[`colibri_types`](/packages/colibri_types.md) when stream records are used.\n"
        if ("avst" in rtl or "axis" in name or dom in ("interfaces", "packet"))
        else f"Width and typing rules: [`CONVENTIONS.md`]({conv}).\n"
    )

    mod_status = "stable" if name in STABLE_MODULES else "draft"
    body = f"""{yaml_frontmatter(type_="Module", title=name, description=desc, tags=tags, resource=rtl, status=mod_status)}

# Purpose

{desc}

# When to use

{when}

# Schema

## Parameters

{param_table}

## Ports

{port_table}

{types_blurb}

# Behaviour

{behaviour}

# Integration

- Verilator: add `{flist}` (or `verilator/colibri.f` for packages) to the compile list.
- RTL path: `{rtl}`.
{imports}
{('- ' + enrich.get('integration', '')) if enrich.get('integration') else ''}
- Upstream entity name matches module name `{name}`.

# Examples

{example}

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| {sim} | {tb} | {sva or 'none'} |

# Agent notes

- Read `{rtl}` before editing; preserve the SPDX header and `` `timescale `` line.
- Match [`CONVENTIONS.md`]({conv}); do not rename ports or packages.
- Run targeted simulation: `{tb}` when present, or `./verilator/run_all.sh` for full regression.
- Compare behaviour against upstream VHDL at the pinned commit when changing logic.

# Related

{chr(10).join('- ' + r for r in related)}
"""
    doc_path.write_text(expand_doc_links(body, doc_path), encoding="utf-8", newline="\n")
    return doc_path


def write_package_page(pkg: str, rtl: str, desc: str) -> Path:
    path = DOCS / "packages" / f"{pkg}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    ver = VERIFICATION.get(pkg, {})
    conv = conventions_href(path)
    pkg_status = "stable" if pkg in STABLE_PACKAGES else "draft"
    body = f"""{yaml_frontmatter(type_="Package", title=pkg, description=desc, tags=["package", pkg.replace("colibri_", "pkg:")], resource=rtl, status=pkg_status)}

# Purpose

{desc}

SystemVerilog package translated from the upstream VHDL library `colibri`. Import with `import {pkg}::*;` after compiling `{rtl}`.

# When to use

Compile this package before any module that imports it. Shared packages are listed in `verilator/colibri.f` in dependency order. Do not rename packages; see [`CONVENTIONS.md`]({conv}).

# Schema

Public API is defined in `{rtl}`. Use the source file as the authoritative list of types, functions, and constants.

# Behaviour

Package functions are either constant functions or class methods per [`CONVENTIONS.md`]({conv}). Simulation-only tasks (e.g. `colibri_binaryio`) are not synthesisable.

# Integration

- Add `{rtl}` via `verilator/colibri.f` or the domain-specific `.f` file that pulls it in.
- VHDL name mapping: see the frozen package table in [`CONVENTIONS.md`]({conv}).

# Examples

```systemverilog
import {pkg}::*;
```

# Verification

| Simulation | Self-checking testbench | SVA |
| --- | --- | --- |
| {ver.get('simulation', 'yes')} | {ver.get('testbench', 'see sim/')} | {ver.get('sva', 'none') or 'none'} |

# Agent notes

- Treat `{rtl}` as a frozen API surface unless the user explicitly requests a breaking change.
- Run package testbenches under `sim/` when changing behaviour.

# Related

- [packages index](/packages/index.md)
- [getting started](/playbooks/getting-started.md)
"""
    path.write_text(expand_doc_links(body, path), encoding="utf-8", newline="\n")
    return path


def write_indexes(modules_by_domain: dict[str, list[str]]) -> None:
    index_path = DOCS / "index.md"
    index_body = """# Colibri SystemVerilog documentation

Canonical module and package documentation for the Verilator-oriented SystemVerilog port of [colibri](https://gitlab.com/colibri-cern/colibri).

## Playbooks

- [Getting started](/playbooks/getting-started.md)
- [Simulation](/playbooks/simulation.md)
- [Stream interfaces](/playbooks/stream-interfaces.md)
- [Typical datapaths](/playbooks/typical-datapaths.md)
- [Agent workflow](/playbooks/agent-workflow.md)

## Reference

- [Conventions summary](/reference/conventions.md)

## Catalog

- [Packages](/packages/index.md)
- [Modules by domain](/modules/index.md)

## Licencing

RTL, simulation, and formal verification files in this repository are **Covered Source** under [CERN-OHL-W-2.0](../LICENSES/CERN-OHL-W-2.0.txt); see [NOTICE](../NOTICE). Per-file SPDX headers on `src/**/*.sv` and the obligations in NOTICE satisfy redistribution of that hardware Source.

The pages under `docs/` are descriptive documentation. They are not hardware Source and do not need `SPDX-FileCopyrightText: 2026 CERN` (or `SPDX-License-Identifier: CERN-OHL-W-2.0`) on every file. Upstream colibri provenance is cited in module `sources` and in RTL headers.

Translation contract (authoritative): [`CONVENTIONS.md`](../CONVENTIONS.md).
"""
    index_path.write_text(expand_doc_links(index_body, index_path), encoding="utf-8", newline="\n")

    (DOCS / "log.md").write_text(
        f"""# Bundle changelog

## 2026-09-26

- Documentation bundle: module/package pages, playbooks (including typical datapaths), and agent entry points.
- Reference modules/packages marked `status: stable` after review pass.
- Generated by `{GENERATED_BY}`.
""",
        encoding="utf-8",
        newline="\n",
    )

    mod_index_lines = ["# Modules\n", "Domain-oriented catalog mirroring `src/`.\n\n", "| Domain | Index |\n| --- | --- |\n"]
    for dom in sorted(modules_by_domain.keys()):
        mod_index_lines.append(f"| `{dom}` | [/modules/{dom}/index.md](/modules/{dom}/index.md) |\n")
    mod_index = DOCS / "modules" / "index.md"
    mod_index.write_text(
        expand_doc_links("\n".join(mod_index_lines), mod_index),
        encoding="utf-8",
        newline="\n",
    )

    for dom, mods in modules_by_domain.items():
        lines = [
            f"# {dom}\n",
            f"Modules under `src/{dom}/`.\n\n",
            "| Module | Description |\n| --- | --- |\n",
        ]
        for m in sorted(mods):
            d = DESCRIPTIONS.get(m, m)
            lines.append(f"| [{m}](/modules/{dom}/{m}.md) | {d} |\n")
        dom_index = DOCS / "modules" / dom / "index.md"
        dom_index.write_text(
            expand_doc_links("".join(lines), dom_index), encoding="utf-8", newline="\n"
        )

    pkg_lines = [
        "# Packages\n\n",
        "| Package | Description |\n| --- | --- |\n",
    ]
    for pkg, (rtl, desc) in PACKAGES.items():
        pkg_lines.append(f"| [{pkg}](/packages/{pkg}.md) | {desc} |\n")
    pkg_index = DOCS / "packages" / "index.md"
    pkg_index.write_text(
        expand_doc_links("".join(pkg_lines), pkg_index), encoding="utf-8", newline="\n"
    )


def write_playbooks() -> None:
    pb = DOCS / "playbooks"
    pb.mkdir(parents=True, exist_ok=True)
    pb_index = pb / "index.md"
    pb_index.write_text(
        expand_doc_links(
            """# Playbooks

| Playbook | Summary |
| --- | --- |
| [getting-started](/playbooks/getting-started.md) | Licence, layout, first integration |
| [simulation](/playbooks/simulation.md) | Verilator regression and file lists |
| [stream-interfaces](/playbooks/stream-interfaces.md) | AVST/AXIS types and adapters |
| [typical-datapaths](/playbooks/typical-datapaths.md) | Common block chains |
| [agent-workflow](/playbooks/agent-workflow.md) | How agents maintain this bundle |
""",
            pb_index,
        ),
        encoding="utf-8",
        newline="\n",
    )

    playbooks = {
        "getting-started.md": (
            "Playbook",
            "Getting started",
            "Licence, repository layout, and first module integration.",
            ["playbook", "onboarding"],
            """# Purpose

Adopt Colibri SystemVerilog modules in a Verilator 5 project.

# Steps

1. Read [`CONVENTIONS.md`](../../CONVENTIONS.md) for naming, packages, and stream types.
2. Pick a module from [modules index](/modules/index.md) or [packages](/packages/index.md).
3. Add `verilator/colibri.f` plus the domain file list (e.g. `verilator/files/common.f`) to your compile script.
4. Import packages with `import colibri_utils::*;` and `import colibri_types::*;` as needed.
5. Run `./verilator/run_all.sh` in this repository to confirm tool versions match CI.

# Licence

CERN-OHL-W-2.0. See `LICENSES/CERN-OHL-W-2.0.txt` and [`NOTICE`](../../NOTICE).

# Related

- [simulation](/playbooks/simulation.md)
- [stream-interfaces](/playbooks/stream-interfaces.md)
""",
        ),
        "simulation.md": (
            "Playbook",
            "Simulation",
            "Verilator 5 regression via run_all.sh and per-domain file lists.",
            ["playbook", "verilator", "simulation"],
            """# Requirements

Verilator 5 with `--timing` and `--assert`.

# Full regression

From the repository root:

```sh
./verilator/run_all.sh
```

The script discovers every `sim/**/*_tb.sv`, selects a matching `verilator/files/*.f` list from the testbench path, builds, runs, and exits non-zero if any test fails.

# File lists

| Path prefix | Typical `.f` file |
| --- | --- |
| `sim/common/` | `verilator/files/common.f` |
| `sim/memory/` | `verilator/files/memory.f` |
| `sim/comms/` | `verilator/files/comms.f` |
| `sim/interfaces/` | `verilator/files/interfaces.f` |
| `sim/packet/`, `sim/pipes/` | `verilator/files/packet_pipes.f` |
| `sim/misc/` | `verilator/files/misc.f` |
| `sim/proto/aurora_64b66b/` | `verilator/files/aurora.f` |

Packages are always pulled in through `verilator/colibri.f`.

# Related

- [getting-started](/playbooks/getting-started.md)
- Module pages list per-module testbenches under **Verification**.
""",
        ),
        "stream-interfaces.md": (
            "Playbook",
            "Stream interfaces",
            "Avalon-ST and AXI-Stream records, adapters, and CDC patterns.",
            ["playbook", "interface:avst", "interface:axis"],
            """# Types

Stream helpers live in [`colibri_types`](/packages/colibri_types.md). In RTL you will see either:

- **Split AVST ports** on modules: `snk_*` (sink) and `src_*` (source) with `valid`/`ready`, plus `sop`/`eop`/`empty` on packet beats.
- **Packed structs** via macros such as `` `COLIBRI_AVST_MASTER_T `` and `` `COLIBRI_AXIS_MASTER_T `` (see [`CONVENTIONS.md`](../../CONVENTIONS.md)).

AXI-Stream uses `tdata`, `tvalid`, `tready`, `tlast`, and `tkeep` (width from `axis_keep_width()`).

# Adapters (`src/interfaces/stream/`)

| Module | Role |
| --- | --- |
| [`avst_to_axis`](/modules/interfaces/avst_to_axis.md) | AVST → AXI-Stream |
| [`axis_to_avst`](/modules/interfaces/axis_to_avst.md) | AXI-Stream → AVST |
| [`avst_width_converter`](/modules/interfaces/avst_width_converter.md) | Beat width change on AVST |
| [`avst_cdc`](/modules/interfaces/avst_cdc.md) | AVST clock-domain crossing |
| [`avst_fifo`](/modules/interfaces/avst_fifo.md) | AVST FIFO wrapper |

RAM writers/readers (`avst_ram_*`) connect streams to on-chip memories; see module pages for aligned vs byte-addressable variants.

# CDC

For arbitrary payloads use [`synchro_generic`](/modules/common/synchro_generic.md) or [`synchro_handshake`](/modules/common/synchro_handshake.md) in `src/common/`. Stream-specific CDC prefers `avst_cdc` or memory FIFOs (`packet_cc_ram_fifo`).

# Macros

Use the helper macros documented in `types.sv` and [`CONVENTIONS.md`](../../CONVENTIONS.md) to connect interfaces without manually wiring every field.

# Related

- [interfaces domain](/modules/interfaces/index.md)
- [colibri_types](/packages/colibri_types.md)
""",
        ),
        "typical-datapaths.md": (
            "Playbook",
            "Typical datapaths",
            "Common module chains for integration (not exhaustive).",
            ["playbook", "integration"],
            """# AVST packet + CRC

[`header_add`](/modules/packet/header_add.md) → payload logic → [`crc`](/modules/comms/crc.md) → [`be_add_trail`](/modules/misc/be_add_trail.md) (optional) → [`packet_fifo`](/modules/memory/packet_fifo.md) or PHY adapter.

# Width / protocol bridge

Narrow AVST → [`avst_width_converter`](/modules/interfaces/avst_width_converter.md) → wide AVST → [`avst_to_axis`](/modules/interfaces/avst_to_axis.md) → AXI-Stream IP.

# Clock crossing

Same-width AVST: [`avst_cdc`](/modules/interfaces/avst_cdc.md) or [`packet_cc_ram_fifo`](/modules/memory/packet_cc_ram_fifo.md). Arbitrary payload: [`synchro_handshake`](/modules/common/synchro_handshake.md).

# CPU packet port

[`mmap_fifo`](/modules/misc/mmap_fifo.md) (Wishbone) ↔ software; AVST TX/RX to the datapath. CSR definitions in [`mmap_fifo_csr_pkg`](/packages/mmap_fifo_csr_pkg.md).

# Line coding

[`scrambler`](/modules/comms/scrambler.md) → PHY or [`encode_8b10b`](/modules/endec/encode_8b10b.md) depending on link. Receive: [`descrambler`](/modules/comms/descrambler.md) or [`decode_8b10b`](/modules/endec/decode_8b10b.md).

# Elasticity

Prefer [`stream_buffer`](/modules/common/stream_buffer.md) between blocks with backpressure; [`avst_fifo`](/modules/interfaces/avst_fifo.md) for packetized FIFO storage.

# Related

- [stream-interfaces](/playbooks/stream-interfaces.md)
- [modules index](/modules/index.md)
""",
        ),
        "agent-workflow.md": (
            "Playbook",
            "Agent workflow",
            "How coding agents read and update the documentation bundle.",
            ["playbook", "agents"],
            """# Bundle root

Documentation lives in [`docs/`](/index.md). RTL remains in `src/`.

# Editing modules

1. Read the module documentation page and its `resource` RTL file.
2. Follow [`docs/MODULE_TEMPLATE.md`](/MODULE_TEMPLATE.md) when creating or restructuring pages.
3. Update the domain [`index.md`](/modules/index.md) if `description` changes.
4. Append significant changes to [`log.md`](/log.md).

# Parallel ownership

Claim one domain under `docs/modules/<domain>/` per change set to avoid merge conflicts.

# Verification

After RTL edits, run the listed testbench or `./verilator/run_all.sh`.

# Related

- [`AGENTS.md`](../../AGENTS.md)
- [`.cursor/skills/documentation/project.md`](../../.cursor/skills/documentation/project.md)
""",
        ),
    }

    for fname, (typ, title, desc, tags, content) in playbooks.items():
        fm = yaml_frontmatter(type_=typ, title=title, description=desc, tags=tags)
        out = pb / fname
        out.write_text(expand_doc_links(fm + "\n" + content, out), encoding="utf-8", newline="\n")

    ref = DOCS / "reference"
    ref.mkdir(parents=True, exist_ok=True)
    ref_index = ref / "index.md"
    ref_index.write_text(
        expand_doc_links("# Reference\n\n- [conventions](/reference/conventions.md)\n", ref_index),
        encoding="utf-8",
        newline="\n",
    )
    conv_ref = conventions_href(ref / "conventions.md")
    conv_path = ref / "conventions.md"
    conv_body = (
        yaml_frontmatter(
            type_="Reference",
            title="Conventions",
            description="Summary pointer to CONVENTIONS.md translation contract.",
            tags=["reference", "conventions"],
        )
        + f"""

# Purpose

[`CONVENTIONS.md`]({conv_ref}) is the authoritative translation contract (types, generics, streams, file headers). This page does not duplicate that prose.

# When to use

Consult `CONVENTIONS.md` before any RTL or documentation change that affects naming, packages, or interfaces.

# Related

- [getting started](/playbooks/getting-started.md)
- [colibri_types](/packages/colibri_types.md)
"""
    )
    conv_path.write_text(expand_doc_links(conv_body, conv_path), encoding="utf-8", newline="\n")


def write_module_template() -> None:
    (DOCS / "MODULE_TEMPLATE.md").write_text(
        """# Module documentation template (internal)

Use this structure for every `type: Module` concept page. Concept ID = path without `.md`.

```yaml
---
type: Module
title: <module_name>
description: <one line>
tags: [domain:<area>, module:<name>]
generated: { by: <actor>, at: <ISO8601Z> }
status: draft
resource: src/<domain>/<module>.sv
---
```

## Required sections

1. **# Purpose**
2. **# When to use**
3. **# Schema** (parameters and ports tables)
4. **# Behaviour**
5. **# Integration**
6. **# Examples**
7. **# Verification**
8. **# Agent notes**
9. **# Related**

Link using bundle-root paths: `[counter](/modules/common/counter.md)`.
""",
        encoding="utf-8",
        newline="\n",
    )


def write_agents_and_project() -> None:
    (ROOT / "AGENTS.md").write_text(
        """# Agent instructions (colibri_sv)

## Documentation

- Documentation root: [`docs/`](docs/index.md).
- Module template: [`docs/MODULE_TEMPLATE.md`](docs/MODULE_TEMPLATE.md).
- Project doc settings: [`.cursor/skills/documentation/project.md`](.cursor/skills/documentation/project.md).

## RTL

- Sources under `src/`. Follow [`CONVENTIONS.md`](CONVENTIONS.md).
- Verify with `sim/**/*_tb.sv` and [`verilator/run_all.sh`](verilator/run_all.sh).

## Regenerating docs

From repo root: `uv run python tools/generate_okf_bundle.py` — refreshes generated module/package pages, playbooks, pointer readmes, and this file. Extend enrichments in `tools/generate_okf_bundle.py` instead of one-off edits that the next regen will overwrite.

## Parallel work

- Own one `docs/modules/<domain>/` tree per change.
- Append meaningful updates to [`docs/log.md`](docs/log.md).
- Do not duplicate `CONVENTIONS.md` in documentation pages; link it.

## Upstream

VHDL reference: commit `3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f` on [colibri-cern/colibri](https://gitlab.com/colibri-cern/colibri).
""",
        encoding="utf-8",
        newline="\n",
    )

    proj = ROOT / ".cursor/skills/documentation"
    proj.mkdir(parents=True, exist_ok=True)
    (proj / "project.md").write_text(
        """# Documentation project settings (colibri_sv)

## Bundle root

`docs/` — start at [`docs/index.md`](../../../docs/index.md).

## Concept types

| type | Use |
| --- | --- |
| Playbook | How-to guides under `docs/playbooks/` |
| Reference | Stable contracts; `CONVENTIONS.md` remains authoritative |
| Package | `colibri_*` and CSR packages |
| Module | One RTL `module` per page |

## Tags

- `domain:<common|memory|comms|endec|io|interfaces|packet|pipes|misc|aurora>`
- `module:<name>`
- `interface:avst`, `interface:axis`, `interface:wishbone`
- `cdc`, `verilator`, `playbook`, `package`

## Workflow

1. Edit RTL in `src/`; update matching `docs/modules/...` page.
2. Keep parameters/ports in sync with elaborated RTL.
3. Update domain `index.md` descriptions when frontmatter changes.
4. Link to playbooks instead of copying stream/CDC prose.
5. Regenerate with `uv run python tools/generate_okf_bundle.py` when the catalog or verification tables change.

## Do not

- Duplicate full `CONVENTIONS.md` text in concept pages.
- Add per-file CERN-OHL-W SPDX blocks under `docs/` (see [Licencing](../../../docs/index.md#licencing)).
- Rename frozen packages or move bundle root without updating `AGENTS.md`.
""",
        encoding="utf-8",
        newline="\n",
    )


def slim_src_readmes() -> None:
    pointers = {
        "src/common/readme.md": "/modules/common/index.md",
        "src/memory/readme.md": "/modules/memory/index.md",
        "src/comms/readme.md": "/modules/comms/index.md",
        "src/endec/readme.md": "/modules/endec/index.md",
        "src/io/readme.md": "/modules/io/index.md",
        "src/interfaces/readme.md": "/modules/interfaces/index.md",
        "src/packet/readme.md": "/modules/packet/index.md",
        "src/pipes/readme.md": "/modules/pipes/index.md",
        "src/misc/readme.md": "/modules/misc/index.md",
        "src/fileio/readme.md": "/packages/colibri_binaryio.md",
        "src/proto/aurora_64b66b/readme.md": "/modules/proto/aurora_64b66b/index.md",
        "src/proto/readme.md": "/modules/proto/aurora_64b66b/index.md",
        "src/io/jtag/readme.md": "/modules/io/jtag_serdes.md",
    }
    for rel, link in pointers.items():
        title = Path(rel).parent.name.replace("_", " ").title()
        (ROOT / rel).write_text(
            f"""# {title}

Canonical documentation: [`docs{link}`](../../docs{link}).

- Playbooks: [getting started](../../docs/playbooks/getting-started.md), [simulation](../../docs/playbooks/simulation.md), [stream interfaces](../../docs/playbooks/stream-interfaces.md).
- Agent entry: [`AGENTS.md`](../../AGENTS.md).
""",
            encoding="utf-8",
            newline="\n",
        )


def update_root_readme_components() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    if "## Documentation" not in readme:
        insert = """

## Documentation

Canonical module and package documentation is under [`docs/`](docs/index.md). Coding agents should start from [`AGENTS.md`](AGENTS.md).

- [Bundle index](docs/index.md)
- [Playbooks](docs/playbooks/index.md)
- [Module catalog](docs/modules/index.md)
- [Packages](docs/packages/index.md)
"""
        anchor = "## Components"
        if anchor in readme:
            readme = readme.replace(anchor, insert + "\n" + anchor, 1)
        else:
            readme = readme.rstrip() + insert + "\n"
        (ROOT / "README.md").write_text(readme, encoding="utf-8", newline="\n")

    components = ROOT / "COMPONENTS.md"
    if "docs/modules/index.md" not in components.read_text(encoding="utf-8"):
        components.write_text(
            """# Component catalog

The machine-readable catalog lives under `docs/`:

- [Bundle index](docs/index.md)
- [Packages](docs/packages/index.md)
- [Modules by domain](docs/modules/index.md)

This file intentionally stays short; domain tables and verification links are maintained under `docs/modules/<domain>/index.md` and per-module pages.
""",
            encoding="utf-8",
            newline="\n",
        )


def main() -> None:
    parse_components()
    assign_module_paths()
    parse_verification_tables()

    modules_by_domain: dict[str, list[str]] = {}
    for name, (dom, rtl) in sorted(MODULE_DOMAIN.items()):
        write_module_page(name, dom, rtl)
        modules_by_domain.setdefault(dom, []).append(name)

    for pkg, (rtl, desc) in PACKAGES.items():
        write_package_page(pkg, rtl, desc)

    write_playbooks()
    write_indexes(modules_by_domain)
    write_module_template()
    write_agents_and_project()
    slim_src_readmes()
    update_root_readme_components()

    n_mod = sum(len(v) for v in modules_by_domain.values())
    n_pkg = len(PACKAGES)
    n_md = len(list(DOCS.rglob("*.md")))
    print(f"Wrote {n_mod} module pages, {n_pkg} package pages, {n_md} total markdown under docs/")


if __name__ == "__main__":
    main()
