// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Comms_crc {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/comms/crc.sv";
        verifPath = "sim/comms/crc_tb.sv";
    }
    part def crc {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_DATA_WIDTH : Integer = 64;
        attribute g_CRC_POLY : String = "colibri_poly::c_CRC_8";
        attribute g_INIT_VAL : String = "{$bits(g_CRC_POLY){1'b0}}";
        attribute g_XOR_OUT : String = "{$bits(g_CRC_POLY){1'b0}}";
        attribute g_INVERT_IN : Boolean = false;
        attribute g_INVERT_OUT : Boolean = false;

        in item clk_i;
        in item reset_i;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_DATA_WIDTH-1:0] snk_data_i";
        in item snk_sop_i;
        in item snk_eop_i;
        in item snk_empty_i;
        attribute snk_empty_i_sv : String = "logic [colibri_types::avst_empty_width(g_DATA_WIDTH, 8)-1:0] snk_empty_i";
        in item snk_valid_i;
        out item snk_ready_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_DATA_WIDTH-1:0] src_data_o";
        out item src_sop_o;
        out item src_eop_o;
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [colibri_types::avst_empty_width(g_DATA_WIDTH, 8)-1:0] src_empty_o";
        out item src_valid_o;
        in item src_ready_i;
        out item src_crc_o;
        attribute src_crc_o_sv : String = "logic [$bits(g_CRC_POLY)-1:0] src_crc_o";
    }

    part crcUse : crc;
}
