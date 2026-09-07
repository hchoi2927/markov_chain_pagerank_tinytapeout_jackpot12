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

which represents an initial probability of 1.0 assigned to the Home page.

## Hardware Architecture
The design consists of four main components:

**markov_top.sv**
Controls the PageRank calculation using a finite-state machine.

It:

- Initializes the PageRank vector.
- Selects one output element at a time.
- Reuses the single MAC unit to accumulate six products.
- Scales the accumulated result back to the 11-bit fixed-point representation.
- Repeats the process for 10 iterations.
- Stores the final six PageRank values for readback.
**mac_unit.sv**
Implements the reusable multiply-accumulate unit.

Two 11-bit values are multiplied to produce a 22-bit product, which is accumulated in a 32-bit register.

**transition_mem.sv**
Stores the 36 entries of the 6×6 transition matrix.

Each group of six transition probabilities sums to 512.

**project.v**
Provides the Tiny Tapeout wrapper and maps the PageRank control and result signals onto the Tiny Tapeout GPIO interface.

## GPIO Interface
### Inputs

| Pin | Signal |
|---|---|
| `ui_in[0]` | `start` |
| `ui_in[1]` | `rd_en` |
| `ui_in[4:2]` | `rd_addr` |

### Outputs

| Pin | Signal |
|---|---|
| `uo_out[0]` | `done` |
| `uo_out[3:1]` | `rd_data[10:8]` |
| `uio_out[7:0]` | `rd_data[7:0]` |

The `uio` pins are configured as outputs.

## Reading Results
After done becomes high, select a PageRank result by placing the desired address on ui_in[4:2] and asserting ui_in[1].

| Address | Page |
|---|---|
| `0` | Home |
| `1` | News |
| `2` | Sports |
| `3` | Shopping |
| `4` | Videos |
| `5` | Maps |

The 11-bit result is reconstructed from:

```bash
uo_out[3:1] = rd_data[10:8]
uio_out[7:0] = rd_data[7:0]
```

## Simulation
The RTL testbench uses cocotb and Icarus Verilog.

From the test directory:

```bash
make -B
```

The testbench resets the design, starts a PageRank calculation, waits for completion, reads all six results, and checks that the resulting fixed-point probabilities sum to approximately 512.

## Tiny Tapeout
This project is configured as a 2×2 Tiny Tapeout design.

The ASIC flow uses the SKY130A PDK and LibreLane.

The repository is configured for Tiny Tapeout submission through the GitHub Actions workflows in .github/workflows/.

## License
This project is licensed under the Apache License 2.0. See LICENSE for details.
