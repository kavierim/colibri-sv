#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
"""One-shot OKF requirements rollout for fv-backed modules. Run from repo root."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs" / "modules"
PARTS = ROOT / "sysml" / "parts"
REQ_SYSML = ROOT / "sysml" / "requirements.sysml"
PIN = "3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f"

# module_key -> (doc relpath under docs/modules, part relpath under sysml/parts, reqs)
# each req: (statement, fv_path, property_name)
MODULES: dict[str, tuple[str, str, list[tuple[str, str, str]]]] = {}

def R(stmt: str, fv: str, prop: str) -> tuple[str, str, str]:
    return (stmt, fv, prop)

def add(key: str, doc: str, part: str, reqs: list[tuple[str, str, str]]) -> None:
    MODULES[key] = (doc, part, reqs)

add(
    "debouncer",
    "common/debouncer.md",
    "common/debouncer.sysml",
    [
        R(
            "After reset_i is low, when data_i matches a constant value for twelve consecutive clock cycles, the next cycle shall drive data_o to that value.",
            "fv/common/debouncer_sva.sv",
            "t_stable_in",
        ),
        R(
            "When data_i changes after one to eleven consecutive cycles matching the previous value, data_o shall remain stable on the next clock edge.",
            "fv/common/debouncer_sva.sv",
            "t_unsstable_in",
        ),
        R(
            "When data_i changes after eleven consecutive cycles matching the previous value, data_o shall remain stable on the next clock edge.",
            "fv/common/debouncer_sva.sv",
            "t_unsstable_in_11",
        ),
    ],
)

add(
    "skid_buffer",
    "common/skid_buffer.md",
    "common/skid_buffer.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low and the skid register shall be empty.", "fv/common/skid_buffer_sva.sv", "t_no_valid_after_reset"),
        R("When src_valid_o is high and src_ready_i is low, src_valid_o and src_data_o shall hold on the next clock edge.", "fv/common/skid_buffer_sva.sv", "t_out_stable_backpressure"),
        R("When a beat is accepted while the output is stalled, the skid register shall capture snk_data_i on the next cycle.", "fv/common/skid_buffer_sva.sv", "t_no_data_drop"),
        R("When src_ready_i is high, snk_valid_i shall equal src_valid_o on the next clock edge.", "fv/common/skid_buffer_sva.sv", "t_idle"),
        R("When the skid register is full and src_ready_i is high, reg_full shall be low on the next cycle.", "fv/common/skid_buffer_sva.sv", "t_reg_read"),
    ],
)

add(
    "pipeline_buffer",
    "common/pipeline_buffer.md",
    "common/pipeline_buffer.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low and internal pipeline state shall be idle.", "fv/common/pipeline_buffer_sva.sv", "t_no_valid_after_reset"),
        R("When src_valid_o is high and src_ready_i is low, src_data_o and src_valid_o shall be stable on the next cycle while reset_i is low.", "fv/common/pipeline_buffer_sva.sv", "t_out_stable_backpressure"),
        R("When stall is high and src_ready_i is high, stall shall be low on the next cycle.", "fv/common/pipeline_buffer_sva.sv", "t_reg_read"),
        R("When the register stage is valid and the output is not ready, incoming data shall move into the skid stage without loss.", "fv/common/pipeline_buffer_sva.sv", "t_no_data_drop"),
        R("When snk_valid_i and snk_ready_o are high, src_valid_o shall be high on the next cycle.", "fv/common/pipeline_buffer_sva.sv", "t_valid_out"),
        R("When no sink or skid data is pending and src_ready_i is high, reg_valid shall clear on the next cycle.", "fv/common/pipeline_buffer_sva.sv", "t_consume_reg"),
    ],
)

add(
    "stream_buffer",
    "common/stream_buffer.md",
    "common/stream_buffer.sysml",
    [
        R("The cycle after reset_i, snk_ready_o shall be high.", "fv/common/stream_buffer_sva.sv", "t_reset_state"),
        R("When snk_ready_o is low, the skid register data shall not change on the next clock edge.", "fv/common/stream_buffer_sva.sv", "t_buffer_stable"),
        R("When snk_valid_i has been high for four cycles without src_valid_o, src_valid_o shall not remain low indefinitely while reset_i is low.", "fv/common/stream_buffer_sva.sv", "t_data_pass"),
    ],
)

add(
    "edge_detect",
    "common/edge_detect.md",
    "common/edge_detect.sysml",
    [
        R("When data_i rises from g_RESET_VAL, pulse_o shall differ from g_RESET_VAL in the same cycle.", "fv/common/edge_detect_sva.sv", "t_valid_pulse"),
        R("When data_i falls to g_RESET_VAL, pulse_o shall equal g_RESET_VAL in the same cycle.", "fv/common/edge_detect_sva.sv", "t_no_pulse_edge"),
        R("When data_i is stable after the first sample, pulse_o shall equal g_RESET_VAL.", "fv/common/edge_detect_sva.sv", "t_no_pulse_stable"),
    ],
)

add(
    "arbiter",
    "pipes/arbiter.md",
    "pipes/arbiter.sysml",
    [
        R("While reset_i is low, grants_o shall be zero or one-hot.", "fv/pipes/arbiter_sva.sv", "a_single_grant"),
        R("When exactly one request is active and reset_i is low, grants_o shall grant that request.", "fv/pipes/arbiter_sva.sv", "a_req_grant"),
        R("When no requests are active and reset_i is low, grants_o shall be all zeros.", "fv/pipes/arbiter_sva.sv", "a_no_grant_if_no_req"),
        R("When the previously granted request remains active, grants_o shall not change.", "fv/pipes/arbiter_sva.sv", "a_stable_grant"),
        R("When the granted request drops but another request remains, grants_o shall change.", "fv/pipes/arbiter_sva.sv", "a_change_grant"),
        R("When the granted-request mask changes, priority_q shall update on the next cycle.", "fv/pipes/arbiter_sva.sv", "a_round_robin"),
    ],
)

_fifo = "fv/memory/fifo_sva.sv"
add(
    "fifo",
    "memory/fifo.md",
    "memory/fifo.sysml",
    [
        R("The cycle after reset_i, empty_o shall be high.", _fifo, "t_after_reset_empty"),
        R("The cycle after reset_i, full_o shall be low.", _fifo, "t_after_reset_n_full"),
        R("The cycle after reset_i, usedw_o shall be zero.", _fifo, "t_after_reset_usedw"),
        R("When usedw_o is zero, empty_o shall be high.", _fifo, "t_usedw_empty"),
        R("When usedw_o equals g_NUM_WORDS, full_o shall be high.", _fifo, "t_usedw_full"),
        R("A write without read while not full shall increment usedw_o by one on the next cycle.", _fifo, "t_wr_no_rd_normal"),
        R("A read without write while not empty shall decrement usedw_o by one on the next cycle.", _fifo, "t_no_wr_rd_normal"),
        R("Simultaneous read and write while neither full nor empty shall hold usedw_o on the next cycle.", _fifo, "t_wr_rd_normal"),
        R("A write while full shall not advance wr_ptr on the next cycle.", _fifo, "t_wr_on_full"),
        R("A read while empty shall not advance rd_ptr on the next cycle.", _fifo, "t_rd_on_empty"),
    ],
)

_rb = "fv/memory/ring_buffer_sva.sv"
add(
    "ring_buffer",
    "memory/ring_buffer.md",
    "memory/ring_buffer.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low and usedw shall be zero.", _rb, "p_reset_state"),
        R("While reset_i is low, usedw shall not exceed g_NUM_WORDS.", _rb, "p_count_max"),
        R("A write while full with no read shall keep usedw at g_NUM_WORDS on the next cycle.", _rb, "p_overwrite_full"),
        R("When usedw is zero, src_valid_o shall be low.", _rb, "p_empty_read"),
        R("When src_valid_o is stalled and the buffer is not full, src_data_o and src_valid_o shall be stable on the next cycle.", _rb, "p_data_stable_norm"),
        R("When snk_valid_i is accepted into non-full storage and src_valid_o is low, src_valid_o shall rise within one cycle.", _rb, "p_data_availability"),
    ],
)

_pkt = lambda n, fv, p: R(n, fv, p)
_hdr = "fv/packet/header_add_sva.sv"
for mod, fv in [
    ("header_add", "fv/packet/header_add_sva.sv"),
    ("header_remove", "fv/packet/header_remove_sva.sv"),
]:
    add(
        mod,
        f"packet/{mod}.md",
        f"packet/{mod}.sysml",
        [
            _pkt("When the output packet state is idle and a beat is presented, src_sop_o shall be high.", fv, "a_valid_out_sop"),
            _pkt("When the output packet state is multi-beat and a beat is presented, src_sop_o shall be low.", fv, "a_valid_out_multi"),
            _pkt("On the last beat of a packet, src_empty_o shall indicate fewer than a full word of valid bytes.", fv, "a_empty_out"),
        ],
    )

add(
    "broadcaster",
    "packet/broadcaster.md",
    "packet/broadcaster.sysml",
    [
        _pkt("On each output port, when idle and a beat is presented, src_sop_o shall be high.", "fv/packet/broadcaster_sva.sv", "a_valid_out_sop"),
        _pkt("On each output port, during a multi-beat packet, src_sop_o shall be low when a beat is presented.", "fv/packet/broadcaster_sva.sv", "a_valid_out_multi"),
    ],
)

add(
    "deinterleaver",
    "packet/deinterleaver.md",
    "packet/deinterleaver.sysml",
    [
        _pkt("On each output, when idle and a beat is presented, src_sop_o shall be high.", "fv/packet/deinterleaver_sva.sv", "a_valid_out_sop"),
        _pkt("On each output, during a multi-beat packet, src_sop_o shall be low when a beat is presented.", "fv/packet/deinterleaver_sva.sv", "a_valid_out_multi"),
        _pkt("While reset_i is low, at most one snk_ready_o shall be high.", "fv/packet/deinterleaver_sva.sv", "a_only_one_snk_active"),
    ],
)

add(
    "interleaver",
    "packet/interleaver.md",
    "packet/interleaver.sysml",
    [
        _pkt("While reset_i is low, snk_ready_o shall be zero or one-hot.", "fv/packet/interleaver_sva.sv", "a_only_one_src_active"),
        _pkt("When the selected input is idle and a beat is output, src_sop_o shall be high.", "fv/packet/interleaver_sva.sv", "a_valid_out_sop"),
        _pkt("When the selected input is in a multi-beat packet, src_sop_o shall be low on output beats.", "fv/packet/interleaver_sva.sv", "a_valid_out_multi"),
        _pkt("A single-beat packet on the output shall mark the corresponding input state as single.", "fv/packet/interleaver_sva.sv", "a_valid_out_single"),
        _pkt("During a multi-beat packet on an input, src_channel_o shall not change while that input is active.", "fv/packet/interleaver_bd_sva.sv", "a_pkt_boundaries"),
    ],
)

add(
    "packet_join",
    "packet/packet_join.md",
    "packet/packet_join.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low and snk_ready_o shall be low.", "fv/packet/packet_join_sva.sv", "a_reset"),
        R("The cycle after reset_i falls, snk_ready_o shall be high.", "fv/packet/packet_join_sva.sv", "a_ready_init"),
        R("When src_valid_o is stalled, output data and packet flags shall remain stable.", "fv/packet/packet_join_sva.sv", "a_out_stable"),
        R("Non-zero src_empty_o shall only occur with src_eop_o.", "fv/packet/packet_join_sva.sv", "a_empty_at_eop_only"),
        R("When the join logic needs a start-of-packet, src_sop_o shall be high on valid output.", "fv/packet/packet_join_sva.sv", "a_first_and_next_sop"),
        R("While waiting for the first output sop, a valid beat shall carry src_sop_o.", "fv/packet/packet_join_sva.sv", "a_out_sop"),
        R("At an output end-of-packet with the expected input symbol count, out_cnt shall match the configured symbol total.", "fv/packet/packet_join_sva.sv", "a_out_cnt"),
    ],
)

add(
    "packet_delay",
    "packet/packet_delay.md",
    "packet/packet_delay.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low.", "fv/packet/packet_delay_sva.sv", "a_reset"),
        R("While reset_i is high, snk_ready_o shall be low.", "fv/packet/packet_delay_sva.sv", "a_ready_mask"),
        R("On the cycle reset_i falls, snk_ready_o shall be high.", "fv/packet/packet_delay_sva.sv", "a_ready_init"),
        R("When src_valid_o is stalled, output data and packet flags shall remain stable.", "fv/packet/packet_delay_sva.sv", "a_out_stable"),
        R("When the delay logic needs a start-of-packet, src_sop_o shall be high on valid output.", "fv/packet/packet_delay_sva.sv", "a_first_and_next_sop"),
        R("On the first output start-of-packet with non-zero configured delay, delay_cnt shall equal the captured delay.", "fv/packet/packet_delay_sva.sv", "a_delay"),
    ],
)

_be = [
    ("be_add_lead", "misc/be_add_lead.md", "misc/be_add_lead.sysml", "fv/misc/be_add_lead_sva.sv"),
    ("be_add_trail", "misc/be_add_trail.md", "misc/be_add_trail.sysml", "fv/misc/be_add_trail_sva.sv"),
    ("be_remove_lead", "misc/be_remove_lead.md", "misc/be_remove_lead.sysml", "fv/misc/be_remove_lead_sva.sv"),
    ("be_remove_trail", "misc/be_remove_trail.md", "misc/be_remove_trail.sysml", "fv/misc/be_remove_trail_sva.sv"),
]
for name, doc, part, fv in _be:
    add(
        name,
        doc,
        part,
        [
            R("When the output packet state is idle and a beat is presented, src_sop_o shall be high.", fv, "a_valid_out_sop"),
            R("When the output packet state is multi-beat, src_sop_o shall be low on presented beats.", fv, "a_valid_out_multi"),
            R("On the last beat of a packet, src_empty_o shall indicate fewer than a full word of valid bytes.", fv, "a_empty_out"),
        ],
    )

add(
    "gearbox",
    "comms/gearbox.md",
    "comms/gearbox.sysml",
    [
        R("For 4-to-12 upsizing, when src_valid_o is high and src_ready_i is low, src_valid_o shall remain high on the next cycle unless reset_i is high.", "fv/comms/gearbox_up_sva.sv", "t_stable_valid_not_ready"),
        R("For 4-to-12 upsizing, when src_valid_o is stalled, src_data_o shall be stable on the next cycle unless reset_i is high.", "fv/comms/gearbox_up_sva.sv", "t_stable_data"),
        R("For 4-to-12 upsizing, the first cycle after reset_i falls, snk_ready_o shall be high, src_valid_o low, and src_data_o zero.", "fv/comms/gearbox_up_sva.sv", "t_valid_reset"),
        R("For 12-to-4 downsizing, when src_valid_o is high and src_ready_i is low, src_valid_o shall remain high on the next cycle unless reset_i is high.", "fv/comms/gearbox_down_sva.sv", "t_stable_valid_not_ready"),
        R("For 12-to-4 downsizing, when src_valid_o is stalled, src_data_o shall be stable on the next cycle unless reset_i is high.", "fv/comms/gearbox_down_sva.sv", "t_stable_data"),
        R("For 12-to-4 downsizing, the first cycle after reset_i falls, snk_ready_o shall be high, src_valid_o low, and src_data_o zero.", "fv/comms/gearbox_down_sva.sv", "t_valid_reset"),
    ],
)

add(
    "rle_encode",
    "endec/rle_encode.md",
    "endec/rle_encode.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low.", "fv/endec/rle_encode_sva.sv", "t_no_valid_after_reset"),
        R("When src_valid_o is stalled, src_data_o shall be stable on the next cycle.", "fv/endec/rle_encode_sva.sv", "t_out_stable_backpressure"),
        R("When a run ends with a normal count, the next output beat shall carry the previous word and its run length.", "fv/endec/rle_encode_sva.sv", "t_rle_out_normal"),
        R("When a run ends at maximum count, the next output beat shall carry the word and the saturated count field.", "fv/endec/rle_encode_sva.sv", "t_rle_out_ovf"),
        R("On flush with buffered data and no output valid, src_valid_o shall present the buffered word on the next cycle.", "fv/endec/rle_encode_sva.sv", "t_rle_flush_empty"),
        R("On flush while output is valid and the register is ready, the next beat shall present the buffered word.", "fv/endec/rle_encode_sva.sv", "t_rle_flush_buffered_no_in"),
        R("On flush after a prior non-flush cycle with skid data pending, the next beat shall present the prior buffered word.", "fv/endec/rle_encode_sva.sv", "t_rle_flush_buffered_no_skid"),
        R("After consecutive flush conditions, src_valid_o shall be low on the following cycle.", "fv/endec/rle_encode_sva.sv", "t_double_flush"),
    ],
)

add(
    "rle_decode",
    "endec/rle_decode.md",
    "endec/rle_decode.sysml",
    [
        R("The cycle after reset_i, src_valid_o shall be low.", "fv/endec/rle_decode_sva.sv", "t_no_valid_after_reset"),
        R("When src_valid_o is stalled, src_data_o shall be stable on the next cycle.", "fv/endec/rle_decode_sva.sv", "t_out_stable_backpressure"),
        R("When a new RLE word is accepted and the output is idle, src_valid_o shall rise with the expanded data word.", "fv/endec/rle_decode_sva.sv", "t_rle_forward"),
        R("When the sink presents a new data value after a gap, the output count field shall match the encoder count.", "fv/endec/rle_decode_sva.sv", "t_rle_count"),
    ],
)

add(
    "axis_to_avst",
    "interfaces/axis_to_avst.md",
    "interfaces/stream/axis_to_avst.sysml",
    [
        R("When the AVST source is idle and presents a beat, src_sop_o shall be high.", "fv/interfaces/stream/axis_to_avst_sva.sv", "a_idle_sop"),
        R("During a multi-beat AVST packet, src_sop_o shall be low on presented beats.", "fv/interfaces/stream/axis_to_avst_sva.sv", "a_multi_no_sop"),
        R("A single-beat AVST packet shall return the source state machine to single-packet mode.", "fv/interfaces/stream/axis_to_avst_sva.sv", "a_single_packet"),
        R("On an end-of-packet beat, src_empty_o shall indicate a partial final word.", "fv/interfaces/stream/axis_to_avst_sva.sv", "a_eop_empty"),
    ],
)

add(
    "avst_to_axis",
    "interfaces/avst_to_axis.md",
    "interfaces/stream/avst_to_axis.sysml",
    [
        R("When AXI stream output is valid and ready, tkeep shall be a one-hot mask.", "fv/interfaces/stream/avst_to_axis_sva.sv", "a_onehot_keep"),
        R("When AXI stream output is valid and ready, tkeep shall not be all zeros.", "fv/interfaces/stream/avst_to_axis_sva.sv", "a_nonempty_keep"),
    ],
)

add(
    "avst_ram_write",
    "interfaces/avst_ram_write.md",
    "interfaces/stream/avst_ram_write.sysml",
    [
        R("The cycle after reset_i, wr_en_o shall be low and write address and data shall be zero.", "fv/interfaces/stream/avst_ram_write_sva.sv", "t_reset_quiet"),
        R("On a valid start-of-packet beat, wr_en_o shall pulse with data and address taken from the beat and start_addr_i.", "fv/interfaces/stream/avst_ram_write_sva.sv", "t_sop_write"),
        R("During an active packet, each valid beat shall produce wr_en_o with the captured snk_data_i.", "fv/interfaces/stream/avst_ram_write_sva.sv", "t_packet_write"),
        R("Successive writes in one packet shall use incrementing wr_addr_o.", "fv/interfaces/stream/avst_ram_write_sva.sv", "t_addr_increment"),
        R("Outside an active packet without a valid beat, wr_en_o shall stay low on the next cycle.", "fv/interfaces/stream/avst_ram_write_sva.sv", "t_wr_en_idle"),
    ],
)

_u = "fv/interfaces/stream/avst_ram_write_unaligned_sva.sv"
add(
    "avst_ram_write_unaligned",
    "interfaces/avst_ram_write_unaligned.md",
    "interfaces/stream/avst_ram_write_unaligned.sysml",
    [
        R("The cycle after reset_i, wr_be_o shall be zero and the FSM shall be in S_IDLE.", _u, "t_reset_idle"),
        R("In S_IDLE without a accepted SOP beat, the FSM shall remain in S_IDLE on the next cycle.", _u, "t_idle_hold"),
        R("An accepted SOP beat in S_IDLE shall move the FSM to S_SOP on the next cycle.", _u, "t_idle_to_sop"),
        R("In S_SOP without the SOP completion condition, the FSM shall not leave S_SOP on the next cycle.", _u, "t_sop_stay"),
        R("After a qualifying EOP in S_SOP, a new SOP handshake shall keep S_SOP.", _u, "t_sop_chain"),
        R("After a qualifying EOP in S_SOP without a new SOP, the FSM shall return to S_IDLE.", _u, "t_sop_to_idle"),
        R("A non-EOP beat after S_SOP shall enter S_WRITE on the next cycle.", _u, "t_sop_to_write"),
        R("A short final word in S_SOP shall move to S_EOP on the next cycle.", _u, "t_sop_to_eop_short"),
        R("An EOP beat in S_SOP shall move to S_EOP on the next cycle.", _u, "t_sop_eop_to_eop"),
        R("In S_WRITE without EOP or flush, the FSM shall stay in S_WRITE.", _u, "t_write_hold"),
        R("An EOP or flush in S_WRITE shall move to S_EOP on the next cycle.", _u, "t_write_to_eop"),
        R("In S_EOP while snk_ready_o is low, the FSM shall remain in S_EOP.", _u, "t_eop_stall"),
        R("In S_EOP with snk_ready_o and no new SOP, the FSM shall return to S_IDLE.", _u, "t_eop_to_idle"),
        R("In S_EOP with snk_ready_o and a new SOP, the FSM shall enter S_SOP.", _u, "t_eop_to_sop"),
        R("Flush in S_SOP or S_WRITE shall move the FSM to S_IDLE or S_EOP.", _u, "t_flush_escape"),
    ],
)

_r = "fv/interfaces/stream/avst_ram_read_sva.sv"
add(
    "avst_ram_read",
    "interfaces/avst_ram_read.md",
    "interfaces/stream/avst_ram_read.sysml",
    [
        R("The cycle after reset_i, busy_o, src_valid_o, and rd_en_o shall be low.", _r, "t_reset_idle"),
        R("After rd_start without backpressure, the next cycle shall enable a read and assert busy_o when needed.", _r, "t_rd_start"),
        R("After a read enable without backpressure, the next cycle shall present rd_data_i on src_data_o with src_valid_o.", _r, "t_data_forward"),
        R("Non-zero src_empty_o shall only occur with src_eop_o.", _r, "t_empty_eop"),
        R("src_sop_o or src_eop_o shall imply src_valid_o.", _r, "t_sop_eop_valid"),
        R("Under backpressure on a non-SOP beat, AVST outputs shall remain stable.", _r, "t_backpressure_stable"),
        R("On the last word of a capped read, busy_o shall be low when rd_en_o is high.", _r, "t_busy_last_word"),
        R("After stop_i, busy_o shall be low on the next cycle.", _r, "t_stop_clears_busy"),
        R("Successive rd_en_o cycles shall use incrementing rd_addr_o while busy.", _r, "t_addr_increment"),
        R("After rd_start with pending output, the first src_valid_o shall carry src_sop_o.", _r, "t_first_sop"),
        R("Before the captured length is emitted, the final beat shall assert src_eop_o.", _r, "t_last_eop"),
        R("On the final beat, src_empty_o shall match the encoded partial word.", _r, "t_last_empty"),
        R("After stop_i with in-flight data, the next handshake shall be an end-of-packet.", _r, "t_stop_eop"),
    ],
)


def module_token(name: str) -> str:
    return name.upper()


def req_id(name: str, n: int) -> str:
    return f"REQ-{module_token(name)}-{n:03d}"


def stub_short(rid: str) -> str:
    parts = rid.split("-")
    return f"REQ_{parts[1]}_{parts[2]}"


def yaml_requirements(name: str, reqs: list[tuple[str, str, str]]) -> str:
    lines = ["requirements:"]
    for i, (stmt, _fv, _p) in enumerate(reqs, 1):
        lines.append(f"  - id: {req_id(name, i)}")
        lines.append(f"    statement: {stmt}")
    return "\n".join(lines)


def requirements_body(name: str, reqs: list[tuple[str, str, str]]) -> str:
    out = [
        "# Requirements",
        "",
        "SHALL sentences are in YAML frontmatter (`requirements[].statement`). This section lists ids, anchors, and verification only.",
        "",
    ]
    for i, (_stmt, fv, prop) in enumerate(reqs, 1):
        rid = req_id(name, i)
        out.append(f'<a id="{rid}"></a>')
        out.append("")
        out.append(f"## {rid}")
        out.append("")
        out.append("- Kind: extracted")
        out.append(f"- Verified by: `{fv}` property `{prop}`")
        out.append("")
    return "\n".join(out)


def patch_frontmatter(text: str, name: str, reqs: list[tuple[str, str, str]]) -> str:
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        raise ValueError("no frontmatter")
    fm = m.group(1)
    body = text[m.end() :]
    if "requirements:" in fm:
        fm = re.sub(r"\nrequirements:.*?(?=\n[a-z_]+:|\Z)", "", fm, flags=re.DOTALL)
    prov = (
        "provenance:\n"
        f"  upstream_path: gitlab.com/colibri-cern/colibri\n"
        f"  pinned_commit: {PIN}\n"
    )
    if "provenance:" not in fm:
        fm = fm.rstrip() + "\n" + prov
    fm = fm.rstrip() + "\n" + yaml_requirements(name, reqs) + "\n"
    return f"---\n{fm}---\n{body}"


def insert_requirements_section(text: str, name: str, reqs: list[tuple[str, str, str]]) -> str:
    if "# Requirements" in text:
        text = re.sub(
            r"# Requirements\s*\n.*?(?=^# |\Z)",
            requirements_body(name, reqs),
            text,
            count=1,
            flags=re.MULTILINE | re.DOTALL,
        )
        return text
    sec = requirements_body(name, reqs)
    for anchor in ("# Integration", "# Assumptions", "# Examples"):
        if anchor in text:
            return text.replace(anchor, sec + anchor, 1)
    raise ValueError("no insertion point")


def patch_md(path: Path, name: str, reqs: list[tuple[str, str, str]]) -> None:
    text = path.read_text(encoding="utf-8")
    text = patch_frontmatter(text, name, reqs)
    text = insert_requirements_section(text, name, reqs)
    path.write_text(text, encoding="utf-8")


def concept_id(doc_rel: str) -> str:
    return "modules/" + Path(doc_rel).with_suffix("").as_posix()


def stub_block(doc_rel: str, rid: str) -> str:
    short = stub_short(rid)
    return f"""
    @OKFReference {{
        docPath = "docs/modules/{doc_rel}";
        conceptId = "{concept_id(doc_rel)}";
        section = "{rid}";
    }}
    requirement def <'{rid}'> {short} {{
        doc /* OKF: docs/modules/{doc_rel}#{rid} */
        require constraint {{ true == true }}
    }}
"""


def patch_part(path: Path, reqs: list[tuple[str, str, str]], name: str) -> None:
    text = path.read_text(encoding="utf-8")
    if "Colibri_Requirements::*" not in text:
        text = text.replace(
            "private import ArchitectureMeta::*;",
            "private import ArchitectureMeta::*;\n    private import Colibri_Requirements::*;",
        )
    satisfies = []
    for i in range(1, len(reqs) + 1):
        satisfies.append(f"        satisfy requirement {stub_short(req_id(name, i))};")
    block = "\n".join(satisfies) + "\n"
    if "satisfy requirement" in text:
        text = re.sub(
            r"\n\s+satisfy requirement REQ_[A-Z0-9_]+;\n",
            "\n",
            text,
        )
    text = re.sub(
        r"(part def \w+ \{[^}]*?)(\n    \})",
        lambda m: m.group(1) + "\n" + block + m.group(2),
        text,
        count=1,
        flags=re.DOTALL,
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    new_stubs: list[str] = []
    for name, (doc_rel, part_rel, reqs) in MODULES.items():
        doc_path = DOCS / doc_rel.replace("/", "\\") if False else DOCS / Path(doc_rel)
        part_path = PARTS / Path(part_rel)
        patch_md(doc_path, name, reqs)
        patch_part(part_path, reqs, name)
        for i in range(1, len(reqs) + 1):
            rid = req_id(name, i)
            new_stubs.append(stub_block(doc_rel, rid))
        print(f"updated {name} ({len(reqs)} reqs)")

    stub_text = REQ_SYSML.read_text(encoding="utf-8")
    if stub_text.rstrip().endswith("}"):
        insert_at = stub_text.rfind("}")
        combined = stub_text[:insert_at] + "".join(new_stubs) + stub_text[insert_at:]
        REQ_SYSML.write_text(combined, encoding="utf-8")
    print(f"stubs appended: {len(new_stubs)}")


if __name__ == "__main__":
    main()
