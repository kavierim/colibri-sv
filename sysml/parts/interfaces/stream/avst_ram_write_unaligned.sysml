// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Interfaces_Stream_avst_ram_write_unaligned {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/interfaces/stream/avst_ram_write_unaligned.sv";
        verifPath = "sim/interfaces/stream/avst_ram_write_unaligned_tb.sv";
        fvPath = "fv/interfaces/stream/avst_ram_write_unaligned_sva.sv";
    }
    part def avst_ram_write_unaligned {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_BYTE_WIDTH : Integer = 8;
        attribute g_WORD_BYTES : Integer = 8;
        attribute g_RAM_DEPTH : Integer = 16;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [c_DATA_W-1:0] snk_data_i";
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [c_EMPTY_W-1:0] snk_empty_i";
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_valid_i;
        out item snk_ready_o;
        in item start_addr_i;
        attribute start_addr_i_sv : String = "logic [c_BYTE_ADDR_W-1:0] start_addr_i";
        in item flush_i;
        out item wr_be_o;
        attribute wr_be_o_sv : String = "logic [g_WORD_BYTES-1:0] wr_be_o";
        out item wr_addr_o;
        attribute wr_addr_o_sv : String = "logic [c_ADDR_W-1:0] wr_addr_o";
        out item wr_data_o;
        attribute wr_data_o_sv : String = "logic [c_DATA_W-1:0] wr_data_o";
    }

    part avstRamWriteUnalignedUse : avst_ram_write_unaligned;
}
