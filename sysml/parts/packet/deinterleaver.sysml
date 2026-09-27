// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Packet_deinterleaver {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/packet/deinterleaver.sv";

        fvPath = "fv/packet/deinterleaver_sva.sv";
    }
    part def deinterleaver {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_OUTPUTS : Integer = 3;
        attribute g_DATA_WIDTH : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_valid_i;
        out item snk_ready_o;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [c_DATA_W-1:0] snk_data_i";
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [c_EMPTY_W-1:0] snk_empty_i";
        in item snk_channel_i;
        attribute snk_channel_i_sv : String = "logic [c_CH_W-1:0] snk_channel_i";
        out item src_sop_o;
        attribute src_sop_o_sv : String = "logic [g_NUM_OUTPUTS-1:0] src_sop_o";
        out item src_eop_o;
        attribute src_eop_o_sv : String = "logic [g_NUM_OUTPUTS-1:0] src_eop_o";
        out item src_valid_o;
        attribute src_valid_o_sv : String = "logic [g_NUM_OUTPUTS-1:0] src_valid_o";
        in item src_ready_i;
        attribute src_ready_i_sv : String = "logic [g_NUM_OUTPUTS-1:0] src_ready_i";
    }
}
