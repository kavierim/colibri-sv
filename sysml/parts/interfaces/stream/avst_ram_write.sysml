// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Interfaces_Stream_avst_ram_write {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/interfaces/stream/avst_ram_write.sv";

        fvPath = "fv/interfaces/stream/avst_ram_write_sva.sv";
    }
    part def avst_ram_write {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 8;
        attribute g_ADDR_WIDTH : Integer = 8;

        in item clk_i;
        in item reset_i;
        in item start_addr_i;
        attribute start_addr_i_sv : String = "logic [g_ADDR_WIDTH-1:0] start_addr_i";
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_valid_i;
        out item wr_en_o;
        out item wr_addr_o;
        attribute wr_addr_o_sv : String = "logic [g_ADDR_WIDTH-1:0] wr_addr_o";
        out item wr_data_o;
        attribute wr_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] wr_data_o";
    }
}
