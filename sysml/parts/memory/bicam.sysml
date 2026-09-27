// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_bicam {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/bicam.sv";
        verifPath = "sim/memory/bicam_tb.sv";
    }
    part def bicam {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_N_WORDS : Integer = 16;
        attribute g_DATA_WIDTH : Integer = 8;

        in item clk_i;
        in item reset_i;
        in item rdreq_i;
        in item wrreq_i;
        in item clear_i;
        in item data_i;
        attribute data_i_sv : String = "logic [g_DATA_WIDTH-1:0] data_i";
        out item full_o;
        out item busy_o;
        out item match_o;
        out item addr_o;
        attribute addr_o_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] addr_o";
    }
}
