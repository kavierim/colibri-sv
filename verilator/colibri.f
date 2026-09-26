// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
//
// Ancillary repository file (not Covered Source). RTL is under CERN-OHL-W; see NOTICE.

// Colibri SystemVerilog file list, dependency order.
// Run from the colibri_sv directory:
//   verilator --lint-only -Wall -Wno-DECLFILENAME -f verilator/colibri.f
//
// Later agents append only their own files, in their own block, below the line.
// Do not reorder Wave 0 files and do not edit another directory's block.

src/common/utils.sv
src/common/types.sv
src/common/encoders.sv
src/common/poly_pkg.sv
src/common/counter.sv
src/memory/mem_pkg.sv
verilator/wave0_elab.sv

// --- append below this line; one block per directory ---
