// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_ring_buffer {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/memory/ring_buffer.sv";
        verifPath = "sim/memory/ring_buffer_tb.sv";
        fvPath = "fv/memory/ring_buffer_sva.sv";
    }
    part def ring_buffer {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_WORDS : Integer = 4;
        attribute g_DATA_WIDTH : Integer = 8;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
        out item src_valid_o;
        in item src_ready_i;
        satisfy requirement REQ_RING_BUFFER_001;
        satisfy requirement REQ_RING_BUFFER_002;
        satisfy requirement REQ_RING_BUFFER_003;
        satisfy requirement REQ_RING_BUFFER_004;
        satisfy requirement REQ_RING_BUFFER_005;
        satisfy requirement REQ_RING_BUFFER_006;

    }

    part ringBufferUse : ring_buffer;
}
