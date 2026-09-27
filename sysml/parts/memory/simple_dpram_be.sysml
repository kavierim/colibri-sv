// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_simple_dpram_be {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/simple_dpram_be.sv";
        verifPath = "sim/memory/simple_dpram_be_tb.sv";
    }
    part def simple_dpram_be {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_BYTE_WIDTH : Integer = 8;
        attribute g_WORD_BYTES : Integer = 4;
        attribute g_N_WORDS : Integer = 16;
        attribute g_INIT_FILE : String = "\"\"";
        attribute g_INIT_WORD : String = "'0";

        in item wrclk_i;
        in item wren_i;
        attribute wren_i_sv : String = "logic [g_WORD_BYTES-1:0] wren_i";
        in item wraddr_i;
        attribute wraddr_i_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] wraddr_i";
        in item wrdata_i;
        attribute wrdata_i_sv : String = "logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] wrdata_i";
        in item rdclk_i;
        in item rden_i;
        in item rdaddr_i;
        attribute rdaddr_i_sv : String = "logic [colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS))-1:0] rdaddr_i";
        out item rddata_o;
        attribute rddata_o_sv : String = "logic [g_WORD_BYTES*g_BYTE_WIDTH-1:0] rddata_o";
    }

    part simpleDpramBeUse : simple_dpram_be;
}
