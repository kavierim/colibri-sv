// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Structural model. Edit this file before the matching SystemVerilog module.
// Baseline extracted from src/ on 2026-09-27.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f

package Colibri_Io_Uart_uart_rx {
    private import ScalarValues::*;
    private import ArchitectureMeta::*;

    @ArtifactTrace {
        rtlPath = "src/io/uart/uart_rx.sv";
    }
    part def uart_rx {
        doc /* Structural contract for the SystemVerilog module. RTL follows this part. */
        attribute g_CLOCK_PERIOD : String = "time'(100ns)";
        attribute g_BAUD_RATE : Integer = 115200;

        in item clk_i;
        in item reset_i;
        out item rx_data_o;
        attribute rx_data_o_sv : String = "logic [7:0] rx_data_o";
        out item rx_valid_o;
        in item rx_pin_i;
    }
}
