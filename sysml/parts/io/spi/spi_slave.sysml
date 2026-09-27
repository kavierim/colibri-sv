// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Io_Spi_spi_slave {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/io/spi/spi_slave.sv";
        verifPath = "sim/io/spi/spi_slave_tb.sv";
    }
    part def spi_slave {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_WORD_SIZE : Integer = 8;
        attribute g_SCK_POLARITY : Boolean = false;
        attribute g_SCK_PHASE : Boolean = false;

        in item clk_i;
        out item miso_o;
        in item mosi_i;
        in item cs_n_i;
        in item sck_i;
        out item src_data_o;
        attribute src_data_o_sv : String = "logic [g_WORD_SIZE-1:0] src_data_o";
        out item src_valid_o;
        in item snk_data_i;
        attribute snk_data_i_sv : String = "logic [g_WORD_SIZE-1:0] snk_data_i";
        in item snk_valid_i;
        out item snk_ready_o;
    }

    part spiSlaveUse : spi_slave;
}
