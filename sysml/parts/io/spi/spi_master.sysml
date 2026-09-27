// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Io_Spi_spi_master {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/io/spi/spi_master.sv";
        verifPath = "sim/io/spi/spi_master_tb.sv";
    }
    part def spi_master {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_CLOCK_PERIOD : String = "time'(25ns)";
        attribute g_SCK_FREQUENCY : String = "1_000_000";
        attribute g_WORD_SIZE : Integer = 8;
        attribute g_SCK_POLARITY : Boolean = false;
        attribute g_SCK_PHASE : Boolean = false;

        in item clk_i;
        in item miso_i;
        out item mosi_o;
        out item cs_n_o;
        out item sck_o;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_WORD_SIZE-1:0] src_data_o";
        out item src_valid_o;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_WORD_SIZE-1:0] snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
    }

    part spiMasterUse : spi_master;
}
