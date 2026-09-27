// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_Optimized_simple_dpram_altera {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/optimized/simple_dpram_altera.sv";
    }
    part def simple_dpram_altera {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 16;
        attribute g_A_DATA_WIDTH : String = "g_DATA_WIDTH";
        attribute g_B_DATA_WIDTH : String = "g_A_DATA_WIDTH";
        attribute g_N_WORDS : Integer = 10;
        attribute g_A_ADDR_WIDTH : String = "colibri_utils::log2ceil(
    colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) * g_N_WORDS / g_A_DATA_WIDTH
  )";
        attribute g_B_ADDR_WIDTH : String = "colibri_utils::log2ceil(
    colibri_utils::maximum(g_A_DATA_WIDTH, g_B_DATA_WIDTH) * g_N_WORDS / g_B_DATA_WIDTH
  )";
        attribute g_REGISTER_OUT : Boolean = false;
        attribute g_INIT_FILE : String = "\"\"";
        attribute g_INIT_WORD : String = "'0";

        in item wrclk_i;
        in item wren_i;
        in item wraddr_i;
        attribute wraddr_i_sv : String = "logic [colibri_utils::downto_width(g_A_ADDR_WIDTH)-1:0] wraddr_i";
        in item wrdata_i;
        attribute wrdata_i_sv : String = "logic [g_A_DATA_WIDTH-1:0] wrdata_i";
        in item rdclk_i;
        in item rden_i;
        in item rdaddr_i;
        attribute rdaddr_i_sv : String = "logic [colibri_utils::downto_width(g_B_ADDR_WIDTH)-1:0] rdaddr_i";
        out item rddata_o;
        attribute rddata_o_sv : String = "logic [g_B_DATA_WIDTH-1:0] rddata_o";
    }
}
