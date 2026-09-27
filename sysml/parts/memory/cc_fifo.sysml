// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_cc_fifo {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/cc_fifo.sv";
        verifPath = "sim/memory/cc_fifo_tb.sv";
    }
    part def cc_fifo {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_WORDS : Integer = 4;
        attribute g_INPUT_WIDTH : Integer = 8;
        attribute g_OUTPUT_WIDTH : String = "g_INPUT_WIDTH";
        attribute g_ENABLE_FWFT : Boolean = false;
        attribute g_PEEK_NEXT : Boolean = false;

        in item reset_i;
        in item wrclk_i;
        in item rdclk_i;
        in item data_i;
        attribute data_i_sv : String = "logic [g_INPUT_WIDTH-1:0] data_i";
        in item wrreq_i;
        in item rdreq_i;
        out item q_o;
        attribute q_o_sv : String = "logic [g_OUTPUT_WIDTH-1:0] q_o";
        out item wrusedw_o;
        attribute wrusedw_o_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS))-1:0] wrusedw_o";
        out item rdusedw_o;
        attribute rdusedw_o_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_NUM_WORDS))-1:0] rdusedw_o";
        out item wrempty_o;
        out item wrfull_o;
        out item rdempty_o;
        out item rdfull_o;
        out item wrq_o;
        attribute wrq_o_sv : String = "logic [g_INPUT_WIDTH-1:0] wrq_o";
        out item wrq_valid_o;
    }
}
