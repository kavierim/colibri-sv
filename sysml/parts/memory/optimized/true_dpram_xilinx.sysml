// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_Optimized_true_dpram_xilinx {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/optimized/true_dpram_xilinx.sv";
    }
    part def true_dpram_xilinx {
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
        attribute g_WRITE_FIRST : Boolean = true;
        attribute g_REGISTER_OUT : Boolean = false;
        attribute g_INIT_FILE : String = "\"\"";
        attribute g_INIT_WORD : String = "'0";

        in item clka_i;
        in item wra_i;
        in item addra_i;
        attribute addra_i_sv : String = "logic [colibri_utils::downto_width(g_A_ADDR_WIDTH)-1:0] addra_i";
        in item dataa_i;
        attribute dataa_i_sv : String = "logic [g_A_DATA_WIDTH-1:0] dataa_i";
        out item dataa_o;
        attribute dataa_o_sv : String = "logic [g_A_DATA_WIDTH-1:0] dataa_o";
        in item clkb_i;
        in item wrb_i;
        in item addrb_i;
        attribute addrb_i_sv : String = "logic [colibri_utils::downto_width(g_B_ADDR_WIDTH)-1:0] addrb_i";
        in item datab_i;
        attribute datab_i_sv : String = "logic [g_B_DATA_WIDTH-1:0] datab_i";
        out item datab_o;
        attribute datab_o_sv : String = "logic [g_B_DATA_WIDTH-1:0] datab_o";
    }

    part trueDpramXilinxUse : true_dpram_xilinx;
}
