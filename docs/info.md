# Markov Chain PageRank Engine

A Tiny Tapeout SystemVerilog implementation of a PageRank engine for a 6×6 Markov-chain transition matrix.

## Overview

This project implements PageRank as an iterative matrix-vector multiplication:

```text
P_next = P_cur × T
```

The design uses:

- A 6×6 transition matrix
- 11-bit fixed-point values
- A scale factor of 512 (`2^9`), where 512 represents 1.0
- One reusable 32-bit multiply-accumulate (MAC) unit
- 10 PageRank iterations
- Six stored output values that can be read through the Tiny Tapeout GPIO interface

The initial PageRank vector is:

```text
[512, 0, 0, 0, 0, 0]
```

This represents an initial probability of 1.0 assigned to the Home page.

## Hardware Architecture

The design consists of four main components.

### `markov_top.sv`

Controls the PageRank calculation using a finite-state machine.

It:

- Initializes the PageRank vector.
- Selects one output element at a time.
- Reuses the single MAC unit to accumulate six products.
- Scales the accumulated result back to the 11-bit fixed-point representation.
- Repeats the process for 10 iterations.
- Stores the final six PageRank values for readback.

### `mac_unit.sv`

Implements the reusable multiply-accumulate unit.

Two 11-bit values are multiplied to produce a 22-bit product, which is accumulated in a 32-bit register.

### `transition_mem.sv`

Stores the 36 entries of the 6×6 transition matrix.

Each row of the transition matrix contains six probabilities that sum to 512, representing a complete probability distribution.

### `project.v`

Provides the Tiny Tapeout wrapper and maps the PageRank control and result signals onto the Tiny Tapeout GPIO interface.

## GPIO Interface

### Inputs

| Pin | Signal |
|---|---|
| `ui_in[0]` | `start` |
| `ui_in[1]` | `rd_en` |
| `ui_in[4:2]` | `rd_addr` |

The remaining dedicated input pins are unused.

### Outputs

| Pin | Signal |
|---|---|
| `uo_out[0]` | `done` |
| `uo_out[3:1]` | `rd_data[10:8]` |

The remaining dedicated output pins are unused.

### Bidirectional GPIO

| Pin | Signal |
|---|---|
| `uio_out[7:0]` | `rd_data[7:0]` |

The `uio` pins are configured as outputs by the Tiny Tapeout wrapper.

## Reading Results

After `done` becomes high, select a PageRank result by placing the desired address on `ui_in[4:2]` and asserting `ui_in[1]` (`rd_en`).

| Address | Page |
|---|---|
| `0` | Home |
| `1` | News |
| `2` | Sports |
| `3` | Shopping |
| `4` | Videos |
| `5` | Maps |

The 11-bit result is reconstructed from the Tiny Tapeout outputs:

```text
uo_out[3:1] = rd_data[10:8]
uio_out[7:0] = rd_data[7:0]
```

## Fixed-Point Arithmetic

The transition probabilities and PageRank values use an 11-bit fixed-point representation with a scale factor of 512.

Therefore:

```text
512 = 1.0
256 = 0.5
128 = 0.25
```

The MAC unit uses a 32-bit accumulator to provide additional precision and prevent overflow during multiplication and accumulation.

After each matrix-vector multiplication, the accumulated value is shifted right by 9 bits to convert the product back to the original fixed-point scale.

## PageRank Calculation

The engine starts with:

```text
P_cur = [512, 0, 0, 0, 0, 0]
```

This assigns the entire initial probability to the Home page.

For each iteration, the engine calculates:

```text
P_next[j] = Σ(P_cur[i] × T[i][j])
```

for each of the six output states.

The single MAC unit is reused to calculate all 36 matrix-vector multiplication terms.

After all six output values have been calculated, `P_next` becomes the input vector for the next iteration.

The engine performs 10 iterations by default.

After the final iteration, the six resulting PageRank values are stored for readback.

## Simulation

The RTL testbench uses cocotb and Icarus Verilog.

From the `test` directory, run:

```bash
make -B
```

The testbench:

1. Resets the design.
2. Starts a PageRank calculation.
3. Waits for the calculation to complete.
4. Checks that `done` is asserted.
5. Reads all six PageRank results.
6. Verifies that each result is within the expected fixed-point range.
7. Checks that the six results sum to approximately 512.

The fixed-point sum may differ slightly from 512 because of integer rounding during the iterative calculations.

## Tiny Tapeout

This project is configured as a **2×2 Tiny Tapeout design**.

The Tiny Tapeout wrapper uses the standard `tt_um_nitikac24_hchoi2927_pagerank` top-level module.

The design uses:

- SystemVerilog
- SKY130A
- SkyWater `sky130_fd_sc_hd` standard cells
- A 50 MHz clock
- 2×2 Tiny Tapeout area

The repository includes GitHub Actions workflows for simulation, GDS generation, FPGA support, and documentation.

## External Hardware

No external hardware is required.

The project uses only the standard Tiny Tapeout clock, reset, dedicated GPIO, and bidirectional GPIO pins.

## License

This project is licensed under the Apache License 2.0. See the `LICENSE` file for details.
