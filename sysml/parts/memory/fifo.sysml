// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_fifo {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/fifo.sv";
        verifPath = "sim/memory/fifo_tb.sv";
        fvPath = "fv/memory/fifo_sva.sv";
    }
    part def fifo {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_WORDS : Integer = 4;
        attribute g_INPUT_WIDTH : Integer = 8;
        attribute g_OUTPUT_WIDTH : String = "g_INPUT_WIDTH";
        attribute g_ENABLE_FWFT : Boolean = false;

        in item clk_i;
        in item reset_i;
        in item data_i;
        attribute data_i_sv : String = "logic [g_INPUT_WIDTH-1:0] data_i";
        in item wrreq_i;
        in item rdreq_i;
        out item q_o;
        attribute q_o_sv : String = "logic [g_OUTPUT_WIDTH-1:0] q_o";
        out item usedw_o;
        attribute usedw_o_sv : String = "logic [colibri_utils::log2ceil(g_NUM_WORDS):0] usedw_o";
        out item empty_o;
        out item full_o;
    }
}
