// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_packet_fifo {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/packet_fifo.sv";
    }
    part def packet_fifo {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_MAX_PACKET_BYTES : Integer = 256;
        attribute g_NUM_PACKETS : Integer = 4;
        attribute g_USEDP_BITS : String = "colibri_utils::log2ceil(g_NUM_PACKETS) + 1";
        attribute g_ENABLE_SIZE_COUNT : Boolean = true;
        attribute g_PKT_SIZE_BITS : String = "colibri_utils::log2ceil(g_MAX_PACKET_BYTES) + 1";
        attribute g_DATA_WIDTH : Integer = 8;

        in item clk_i;
        in item reset_i;
        out item full_o;
        out item empty_o;
        out item usedp_o;
        attribute usedp_o_sv : String = "logic [g_USEDP_BITS-1:0] usedp_o";
        out item snk_ready_o;
        in item snk_valid_i;
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] snk_empty_i";
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item src_ready_i;
        out item src_valid_o;
        out item src_sop_o;
        out item src_eop_o;
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_DATA_WIDTH / 8))-1:0] src_empty_o";
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
        out item src_size_o;
        attribute src_size_o_sv : String = "logic [g_PKT_SIZE_BITS-1:0] src_size_o";
    }

    part packetFifoUse : packet_fifo;
}
