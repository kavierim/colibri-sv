// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Packet_packet_delay {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/packet/packet_delay.sv";
        verifPath = "sim/packet/packet_delay_tb.sv";
        fvPath = "fv/packet/packet_delay_sva.sv";
    }
    part def packet_delay {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_SYM_WIDTH : Integer = 8;
        attribute g_DATA_SYM : Integer = 4;
        attribute g_N_PACKETS : Integer = 3;
        attribute g_NUM_BEATS : Integer = 8;
        attribute g_DELAY_WIDTH : Integer = 4;

        in item clk_i;
        in item reset_i;
        in item delay_i;
        attribute delay_i_sv : String = "logic [g_DELAY_WIDTH-1:0] delay_i";
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [c_DATA_W-1:0] snk_data_i";
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [c_EMPTY_W-1:0] snk_empty_i";
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [c_DATA_W-1:0] src_data_o";
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [c_EMPTY_W-1:0] src_empty_o";
        out item src_sop_o;
        out item src_eop_o;
        out item src_valid_o;
        in item src_ready_i;
        satisfy requirement REQ_PACKET_DELAY_001;
        satisfy requirement REQ_PACKET_DELAY_002;
        satisfy requirement REQ_PACKET_DELAY_003;
        satisfy requirement REQ_PACKET_DELAY_004;
        satisfy requirement REQ_PACKET_DELAY_005;
        satisfy requirement REQ_PACKET_DELAY_006;

    }

    part packetDelayUse : packet_delay;
}
