// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Interfaces_Memory_mapped_wb_ram {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/interfaces/memory_mapped/wb_ram.sv";
        verifPath = "sim/interfaces/memory_mapped/wb_ram_tb.sv";
    }
    part def wb_ram {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_N_WORDS : Integer = 16;
        attribute g_WB_DATA_WIDTH : Integer = 32;
        attribute g_WB_ADDR_WIDTH : Integer = 32;

        in item clk_i;
        in item reset_i;
        in item wb_adr_i;
        attribute wb_adr_i_sv : String = "logic [g_WB_ADDR_WIDTH-1:0] wb_adr_i";
        in item wb_dat_i;
        attribute wb_dat_i_sv : String = "logic [g_WB_DATA_WIDTH-1:0] wb_dat_i";
        out item wb_dat_o;
        attribute wb_dat_o_sv : String = "logic [g_WB_DATA_WIDTH-1:0] wb_dat_o";
        in item wb_we_i;
        in item wb_sel_i;
        attribute wb_sel_i_sv : String = "logic [c_SEL_W-1:0] wb_sel_i";
        in item wb_stb_i;
        in item wb_cyc_i;
        out item wb_ack_o;
        out item wb_err_o;
    }

    part wbRamUse : wb_ram;
}
