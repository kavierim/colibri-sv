// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Memory_cc_ram_fifo {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/memory/cc_ram_fifo.sv";
        verifPath = "sim/memory/cc_ram_fifo_tb.sv";
    }
    part def cc_ram_fifo {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_NUM_WORDS : Integer = 4;
        attribute g_INPUT_WIDTH : Integer = 8;
        attribute g_OUTPUT_WIDTH : String = "g_INPUT_WIDTH";
        attribute g_ENABLE_FWFT : Boolean = false;
        attribute g_INPUT_USEDW_WIDTH : String = "colibri_utils::log2ceil(
    colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH) * g_NUM_WORDS / g_INPUT_WIDTH
  )";
        attribute g_OUTPUT_USEDW_WIDTH : String = "colibri_utils::log2ceil(
    colibri_utils::maximum(g_INPUT_WIDTH, g_OUTPUT_WIDTH) * g_NUM_WORDS / g_OUTPUT_WIDTH
  )";
        attribute g_IMPL_STYLE : String = "colibri_utils::get_compiler()";

        in item reset_i;
        in item wrclk_i;
        in item data_i;
        attribute data_i_sv : String = "logic [g_INPUT_WIDTH-1:0] data_i";
        in item wrreq_i;
        out item wrusedw_o;
        attribute wrusedw_o_sv : String = "logic [colibri_utils::downto_width(g_INPUT_USEDW_WIDTH)-1:0] wrusedw_o";
        out item wrempty_o;
        out item wrfull_o;
        in item rdclk_i;
        in item rdreq_i;
        out item q_o;
        attribute q_o_sv : String = "logic [g_OUTPUT_WIDTH-1:0] q_o";
        out item rdusedw_o;
        attribute rdusedw_o_sv : String = "logic [colibri_utils::downto_width(g_OUTPUT_USEDW_WIDTH)-1:0] rdusedw_o";
        out item rdempty_o;
        out item rdfull_o;
    }
}
