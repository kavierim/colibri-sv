<!--
SPDX-FileCopyrightText: 2026 CERN
SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
SPDX-License-Identifier: CERN-OHL-W-2.0

Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
Translated from VHDL to SystemVerilog.
Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
-->

# Colibri SystemVerilog conventions

This file is the contract for every later translation. `counter` in `src/common/counter.sv` is the style reference.

## Frozen files

These packages are the shared API. Do not rename them. `verilator/colibri.f` lists them in dependency order. `LICENSES/CERN-OHL-W-2.0.txt` stays unmodified.

| VHDL library `colibri` | SystemVerilog package | File |
| --- | --- | --- |
| `utils` | `colibri_utils` | `src/common/utils.sv` |
| `types` | `colibri_types` | `src/common/types.sv` |
| `encoders` | `colibri_encoders` | `src/common/encoders.sv` |
| `poly` | `colibri_poly` | `src/common/poly_pkg.sv` |
| `mem` | `colibri_mem` | `src/memory/mem_pkg.sv` |

`utils` is too generic as a SystemVerilog package name, so the prefix is `colibri_`. The same prefix is used for the other four packages.

## File layout and headers

The tree mirrors the upstream sources: `src/`, and later `sim/` and `fv/`. One VHDL entity becomes one module in the matching `.sv` file. There is no architecture name. File names stay the VHDL stem (`counter.vhdl` -> `counter.sv`).

Every new file starts with:

```systemverilog
// SPDX-FileCopyrightText: 2026 CERN
// SPDX-FileCopyrightText: 2026 Kari Vierimaa, Kempele, Finland
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Modified: 2026-09-25, Kari Vierimaa, Kempele, Finland.
// Translated from VHDL to SystemVerilog.
// Upstream: https://gitlab.com/colibri-cern/colibri commit 3fa784121ccea86d9e65b2e0dc08d2a3327f5f2f
```

Use `<!-- -->` in Markdown and `#` in plain text. Keep the PoC Library sentence in any translation of a file that has it upstream. Keep the CERN copyright line on **translated RTL** (`src/`, `sim/`, `fv/`). The OKF bundle under `docs/` is descriptive documentation: no per-file CERN-OHL-W SPDX block (see [Licencing](docs/index.md#licencing) on the bundle index). SystemVerilog sources use LF line endings. `LICENSES/CERN-OHL-W-2.0.txt` is an unmodified copy, including its CRLF line endings, and it has no added header.

Every `.sv` file sets `` `timescale 1ns/1ps `` after the header.

## Types and parameters

| VHDL | SystemVerilog |
| --- | --- |
| `std_logic`, `std_ulogic` | `logic` |
| `std_logic_vector(N-1 downto 0)` | `logic [N-1:0]` |
| `unsigned(N-1 downto 0)` | `logic [N-1:0]` |
| `signed(N-1 downto 0)` | `logic signed [N-1:0]` |
| `boolean` generic | `parameter bit` |
| `natural` / `positive` / `integer` generic | `parameter int` or `parameter int unsigned` |
| `time` generic | `parameter time` |
| `string` generic | `parameter string` |
| `type data_t` generic | `parameter type data_t = logic [7:0]` |

Arithmetic on a `logic [N-1:0]` value is unsigned. Write the width on the literal: `counter_int + c_WIDTH'(1)`. Cast with `signed'(expr)` only where the VHDL value is `signed`.

Index 0 is the LSB on a `[N-1:0]` vector. That matches VHDL `downto`. Keep an ascending VHDL array as `[0:N-1]` and a descending one as `[N-1:0]`.

A VHDL null range `(0-1 downto 0)` is not a SystemVerilog range. `[ -1 : 0 ]` is a 2-bit vector. When `log2ceil` can return 0, declare the vector with `downto_width`:

```systemverilog
localparam int c_AW = colibri_utils::downto_width(colibri_utils::log2ceil(g_N_WORDS));
logic [c_AW-1:0] addr;
```

For `g_N_WORDS >= 2`, `downto_width` returns the same integer as its argument.

`parameter type` is the generic-type mapping, for `synchro_generic` and `stream_buffer_generic`:

```systemverilog
module synchro_generic #(
  parameter type data_t = logic [7:0],
  parameter int g_N_STAGES = 2
) (
  input  data_t data_i,
  output data_t data_o
);
```

## Constant functions

Import the names you call. A wildcard `import colibri_types::*;` makes Verilator `-Wall` report every package `localparam` the module does not reference.

These functions are constant-callable. Use them in parameter defaults and port widths. The call is `colibri_utils::log2ceil(...)` in a parameter list, because an `import` inside the module does not apply to the header.

| Call | Meaning |
| --- | --- |
| `log2ceil(arg)` | `ceil(log2(arg))` for `arg >= 0`. Returns 0 when `arg` is 0 or 1. |
| `div_ceil(a, b)` | `ceil(a / b)` for non-negative `a` and positive `b`. |
| `minimum(a, b)`, `maximum(a, b)` | Integer min/max. VHDL took these from `ieee.math_real`. Equal inputs return `b`. |
| `greatest_common_div(n1, n2)` | Euclidean gcd. |
| `least_common_mult(n1, n2)` | `n1 * n2 / gcd`, product in 64 bits. |
| `downto_width(n)` | `n` when `n >= 1`, otherwise 1. |
| `if_sel(condition, pos, neg)` | Integer if-then-else. `condition` is `bit`. |
| `div_ceil_time(a, b)` | `ceil(a / b)` for positive `time` values. Returns `int`. This is the debouncer overload. |
| `div_ceil_time_by_int(a, b)` | `ceil(a / b)` with integer `b`. Returns `time`. |
| `get_compiler()` | `AUTO` under Verilator. |
| `compiler_is_quartus()`, `compiler_is_vivado()` | 0 under Verilator. Quartus/Vivado translate-off comments are kept. |
| `axis_keep_width(tdata_width)` | `div_ceil(tdata_width, 8)`, in `colibri_types`. |
| `avst_empty_width(data_width, symbol_width)` | `maximum(log2ceil(data_width / symbol_width), 1)`, in `colibri_types`. |

`compiler_t` is `{AUTO, QUARTUS, VIVADO}`. `endian_t` is `{BIG, LITTLE}` in `colibri_types`.

Verilator 5.020 accepts these package functions in parameter expressions. It rejects a static method call there (`bits#(8)::invert(...)` is "dotted expressions in parameters"). Width-dependent helpers are class methods and are for assignments, not for parameter expressions.

## Width-dependent helpers

Specialise the class with the vector width. After `import colibri_utils::*;`:

| VHDL | SystemVerilog |
| --- | --- |
| `div_ceil(unsigned, positive)` | `uval#(W)::div_ceil(a, b)` |
| `log2ceil(unsigned, bits)` | `uval#(W)::log2ceil(arg, bits)` (`bits` is unused, as in VHDL) |
| `count_ones`, `invert_bit_order`, `swap_endianness` | `bits#(W)::...` |
| `xorvec`, `andvec`, `gen_even`, `gen_odd` | `bits#(W)::...` |
| `if_sel` on `unsigned` / `signed` / `std_logic_vector` | `bits#(W)::if_sel` |
| `slice_bytes_left/right`, `slice_bytes` (natural) | `byteslice#(W)::...` |
| `slice_bytes` (unsigned pos) | `byteslice_u#(W)::slice_bytes` |
| `mask_bytes_left(pos, size)` | `byte_mask#(size)::mask_bytes_left(pos)` |

`gen_even()` and `gen_odd()` take the width from the class parameter. `W` below 1 is elaborated as 1.

## Records and arrays

Entity ports stay separate signals, as in the VHDL. Records are for internal variables.

Constrained records are real packed structs in `colibri_types`: `axil_wr_master_t`, `axil_wr_slave_t`, `axil_rd_master_t`, `axil_rd_slave_t`, `axis_slave_t`, `avst_slave_t`. Init constants keep the VHDL names: `c_AXIL_WR_MASTER_INIT`, `c_AXIL_WR_SLAVE_INIT`, `c_AXIL_RD_MASTER_INIT`, `c_AXIL_RD_SLAVE_INIT`, `c_AXIS_SLAVE_INIT`, `c_AVST_SLAVE_INIT`. `wstrb` resets to all ones.

`axis_master_t` and `avst_master_t` have no unconstrained struct. Declare one with a localparam for any width expression that contains a comma, then the macro:

```systemverilog
localparam int c_KEEP_W = colibri_types::axis_keep_width(g_DATA_WIDTH);
localparam int c_EMPTY_W = colibri_types::avst_empty_width(g_DATA_WIDTH, g_SYM_WIDTH);
`COLIBRI_AXIS_MASTER_T(axis_t, g_DATA_WIDTH, c_KEEP_W);
`COLIBRI_AVST_MASTER_T(avst_t, g_DATA_WIDTH, c_EMPTY_W);
axis_t bus;
assign bus = `COLIBRI_AXIS_MASTER_INIT;
```

The same objects are classes. These are the init functions later RTL calls:

```systemverilog
colibri_types::axis#(g_DATA_WIDTH)::master_t axis_v;
colibri_types::avst#(g_DATA_WIDTH, g_SYM_WIDTH)::master_t avst_v;
axis_v = colibri_types::axis#(g_DATA_WIDTH)::master_init();
avst_v = colibri_types::avst#(g_DATA_WIDTH)::master_init(); // symbol width defaults to 8
```

Macro arguments must not contain commas. Array macros take the index bounds and the element width:

```systemverilog
`COLIBRI_SLV_ARRAY(lanes, 0, g_N_LANES - 1, c_W);
`COLIBRI_UNS_ARRAY(counts, g_N - 1, 0, c_EW);
`COLIBRI_SLV_ARRAY_2D(memory, 0, g_N_WORDS - 1, 0, g_RATIO - 1, c_CELL_W);
```

The same shape exists for `SIG`, `INT`, `NAT`, and `POS`, and for AXI-Lite / slave arrays (`COLIBRI_AXIL_WR_MASTER_ARRAY`, `COLIBRI_AXIS_SLAVE_ARRAY`, `COLIBRI_AVST_SLAVE_ARRAY`, and the other AXI-Lite directions).

`logic` replaces both `std_logic_vector` and `unsigned` in those arrays. A signed array uses `COLIBRI_SIG_ARRAY`.

Conversion and shifts assume indices `0 .. N-1`. Element 0 is packed into the MSBs, matching the VHDL loops.

| VHDL | SystemVerilog |
| --- | --- |
| `slv_array_to_slv` / `slv_to_slv_array` | `slv_arr#(N, W)::to_slv` / `from_slv` |
| `shift_left` / `shift_right` on `slv_array_t` | `slv_arr#(N, W)::shift_left_arr` / `shift_right_arr` |
| `uns_array_to_slv` | `uns_arr#(N, SRC_W, DST_W)::to_slv` |
| `slv_to_uns_array` | `uns_arr#(N, DST_W, DST_W)::from_slv` |
| `uns_array_to_int_array` | `uns_arr#(N, SRC_W)::to_int` |
| `int_array_to_uns_array` | `uns_arr#(N, W, W)::from_int` |
| `sum` on `uns_array_t` / `sig_array_t` / `int_array_t` | `uns_arr#(N, W)::sum_uns`, `sig_arr#(N, W)::sum_sig`, `int_arr#(N)::sum_int` |
| `bool_to_sl` / `sl_to_int` | `colibri_types::bool_to_sl` / `sl_to_int` |

## Encoders and polynomials

| VHDL | SystemVerilog |
| --- | --- |
| `bin2gray(unsigned)` / `gray2bin` to `unsigned` | `enc#(W)::bin2gray` / `gray2bin` |
| `bin2gray(natural, max)` | `enc#(downto_width(log2ceil(max)))::bin2gray_nat(arg)` |
| `gray2bin` to `natural` | `enc#(W)::gray2bin_nat` |
| `bin2onehot(unsigned)` | `onehot_enc#(BIN_W)::bin2onehot` (width `2**BIN_W`; keep `BIN_W` small) |
| `onehot2bin(std_logic_vector)` | `onehot_dec#(OH_W)::onehot2bin` |
| `bin2onehot(unsigned, max)` / `onehot2bin(..., max)` | `onehot_lim#(MAX)::bin2onehot` / `onehot2bin` |
| `priority_encode` | `pri#(W)::priority_encode` |
| `bin2bcd` / `bcd2bin` | `bin2bcd(int)` / `bcd2bin(logic [3:0])` |

`priority` is a SystemVerilog keyword, so the class is `pri`. `priority_encode` scans from the MSB, matching a VHDL `downto` range. `onehot2bin` keeps the last `'1'` from index 0 upward.

Polynomials are `localparam` vectors in `colibri_poly`: `c_CRC_1`, `c_CRC_3_GSM`, `c_CRC_5_USB`, `c_CRC_8`, `c_CRC_16_CCITT`, `c_CRC_32`, `c_SCR_10GBASE`, `c_PRBS_5`, `c_PRBS_7`, `c_PRBS_15`, `c_PRBS_23`, `c_PRBS_31`. Widths match the VHDL constants. A generic that was an unconstrained `std_logic_vector` takes the constant's width explicitly.

## Memory init and the RAM pattern

```systemverilog
logic [g_DATA_WIDTH-1:0] memory [0:g_N_WORDS-1];
initial memory = colibri_mem::flat#(g_DATA_WIDTH, g_N_WORDS)::init_mem_hex(
  g_INIT_FILE, g_DATA_WIDTH'(g_INIT_WORD)
);
```

The two-dimensional overload is `colibri_mem::grid#(CELL_SIZE, WORD_SIZE, RAM_SIZE)::init_mem_hex`. Cell 0 of each word is the MSBs of the hex word. The cast `CELL'(init_word)` is unsigned resize.

A `shared variable` memory becomes a `logic` array and `always_ff`. This is the pattern `simple_dpram` and the other RAMs will use. Vendor files under `optimized/` stay behavioural descriptions for BRAM inference. They do not instantiate vendor primitives.

```systemverilog
logic [c_WIDTH-1:0] memory [0:c_DEPTH-1];

always_ff @(posedge wrclk_i) begin
  if (wren_i)
    memory[wraddr] <= wrdata_i;
end

always_ff @(posedge rdclk_i) begin
  if (rden_i)
    rddata_q <= memory[rdaddr];
end
```

## `registered`

VHDL `y <= x when registered(clk, g_REGISTER_OUT)` is a clock-edge guard, not a Boolean function. Expand it with a unique label:

```systemverilog
`COLIBRI_WHEN_REGISTERED(data_o, clk_i, g_REGISTER_OUT, data_o, data_q)
```

`g_REGISTER_OUT` is `parameter bit`. The true branch is `always_ff @(posedge clk)`. The false branch is a continuous assignment.

## Processes, generates, asserts

A clocked VHDL process becomes `always_ff @(posedge clk_i)`. Reset that sits inside `rising_edge` stays synchronous. Name the block (`begin : proc_cnt`). Name every generate (`begin : gen_wrap`). An elaboration `assert ... severity failure` becomes:

```systemverilog
if (width_is_too_small) begin : gen_width_check
  $error("ERROR: ...");
end
```

## Testbenches and SVA

Verilator is 2-state. Replace `'X'` and `'U'` with `1'b0` or `1'b1`. Clocks use `` `timescale 1ns/1ps `` and `#delay`:

```systemverilog
`timescale 1ns/1ps
initial clk_i = 1'b0;
always #5 clk_i = ~clk_i;
```

The simulation command, not the lint command, is `verilator --timing --binary --assert -f verilator/colibri.f`. Check failures with `$fatal`. PSL becomes SVA in a `bind` file.

## Verilator

Lint from the `colibri_sv` directory:

```text
verilator --lint-only -Wall -Wno-DECLFILENAME -f verilator/colibri.f
```

Lint was checked with Verilator 5.020. `-Wno-DECLFILENAME` is required because package files do not use the file name as a module name.

Inline waivers already in the packages:

- `UNUSEDSIGNAL` on `enc#(W)::bin2gray_nat`, because the `int` argument is narrowed to `W` bits.
- `UNUSEDSIGNAL` on `byte_mask#(SIZE)::mask_bytes`, because VHDL ignores `pos_r`.

`byteslice_u` is the unsigned `slice_bytes` overload. Specialising it builds a mask of `W*8` bits and uses the low `W` bits. `-Wall` may report the high bits as unused. Leave that function uncalled unless a module needs that exact overload, and waive `UNUSEDSIGNAL` at that call if Verilator reports it.

## Deviations from the VHDL

- Package names carry the `colibri_` prefix. There is no VHDL library name.
- Overload sets are package functions plus class specialisations. Verilator 5.020 has no overload resolution we can rely on for these signatures.
- `unsigned` and `std_logic_vector` ports are both `logic [N-1:0]`.
- `get_compiler` does not `report` a string, so it stays a constant function. The translate-off probes are unchanged, so Verilator returns `AUTO`.
- `registered` is the macro above.
- `counter` with the unused default `g_MODULO = 0` and `g_COUNTER_WIDTH = 0` elaborates a 1-bit port. VHDL gave that default a null port. Any explicit width of at least 1 is unchanged.
- `onehot2bin` returns 0 when no bit is set. VHDL left that result `'U'`.
- A short or empty init file fills the remaining words with 0. VHDL left them `'U'`. A missing file calls `$fatal`.
- `hread` is a hex-line parse: `ceil(width/4)` digits, and the value must fit. A short token ends the load. Extra digits on the same line are ignored.
- `mask_bytes` ignores `pos_r` and returns 0, because the VHDL ANDs a mask with its inverse.
- `uns_arr::to_slv` keeps the inverted VHDL assert: it warns when `DST_W == SRC_W`.
- `gen_even` / `gen_odd` test bit 0 of the index. VHDL built a `log2ceil(len)`-wide unsigned, which is a null range when `len` is 1.
- `div_ceil_time` ceils in the simulation time unit (1 ps). It does not model a 1 fs addend below that precision.
- `bcd2bin` accepts only a 4-bit vector, so the VHDL length assertion is the type.
- `priority_encode` assumes a `downto` vector (MSB first).
