// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Interfaces_Stream_avst_ram_read {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;
    private import Colibri_Requirements::*;

    @ArtifactTrace {
        rtlPath = "src/interfaces/stream/avst_ram_read.sv";

        fvPath = "fv/interfaces/stream/avst_ram_read_sva.sv";
    }
    part def avst_ram_read {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_BYTE_WIDTH : Integer = 8;
        attribute g_WORD_BYTES : Integer = 8;
        attribute g_RAM_DEPTH : Integer = 16;

        in item clk_i;
        in item reset_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [c_DATA_W-1:0] src_data_o";
        out item src_empty_o;
        attribute src_empty_o_sv : String = "logic [c_EMPTY_W-1:0] src_empty_o";
        out item src_sop_o;
        out item src_eop_o;
        out item src_valid_o;
        in item src_ready_i;
        in item start_addr_i;
        attribute start_addr_i_sv : String = "logic [c_ADDR_W-1:0] start_addr_i";
        in item length_i;
        attribute length_i_sv : String = "logic [c_LEN_W-1:0] length_i";
        in item start_i;
        in item stop_i;
        out item busy_o;
        out item rd_en_o;
        out item rd_addr_o;
        attribute rd_addr_o_sv : String = "logic [c_ADDR_W-1:0] rd_addr_o";
        in item rd_data_i;
        attribute rd_data_i_sv : String = "logic [c_DATA_W-1:0] rd_data_i";
        satisfy requirement REQ_AVST_RAM_READ_001;
        satisfy requirement REQ_AVST_RAM_READ_002;
        satisfy requirement REQ_AVST_RAM_READ_003;
        satisfy requirement REQ_AVST_RAM_READ_004;
        satisfy requirement REQ_AVST_RAM_READ_005;
        satisfy requirement REQ_AVST_RAM_READ_006;
        satisfy requirement REQ_AVST_RAM_READ_007;
        satisfy requirement REQ_AVST_RAM_READ_008;
        satisfy requirement REQ_AVST_RAM_READ_009;
        satisfy requirement REQ_AVST_RAM_READ_010;
        satisfy requirement REQ_AVST_RAM_READ_011;
        satisfy requirement REQ_AVST_RAM_READ_012;
        satisfy requirement REQ_AVST_RAM_READ_013;

    }

    part avstRamReadUse : avst_ram_read;
}
