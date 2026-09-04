<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a hardware PageRank engine based on a 6×6 Markov-chain transition matrix.

The design models six pages:
  Home
  News
  Sports
  Shopping
  Videos
  Maps
The transition matrix is stored in transition_mem.sv. Each matrix entry uses 11-bit fixed-point representation with a scale factor of 512, where:
  512 represents 1.0
  256 represents 0.5
  128 represents 0.25
Each row of the transition matrix sums to 512, representing a probability distribution.

The PageRank calculation repeatedly performs matrix-vector multiplication. The current PageRank vector is multiplied by the transition matrix to produce the next vector.

The design contains six parallel multiply-accumulate (MAC) units. The MAC units process the matrix-vector multiplication in parallel, accumulating the contributions for the six output elements.

The calculation starts with the initial PageRank vector:
  [512, 0, 0, 0, 0, 0]
which represents all initial probability assigned to the Home page.

The engine performs 10 iterations by default. After the final iteration, the resulting six PageRank values are stored and can be read through the output interface.

Control signals
The internal markov_top module has the following interface:
Signal   Description
start    Starts a new PageRank calculation
done     Indicates that the final result is ready
rd_en    Enables reading a result
rd_addr  Selects which PageRank value to read
rd_data	 Selected 11-bit PageRank value
clk      Clock
rst_n	   Active-low reset

The Tiny Tapeout wrapper maps these signals onto the standard Tiny Tapeout GPIO interface.

Fixed-point arithmetic
The transition probabilities and PageRank values use a scale factor of 512.

The MAC units use a 32-bit accumulator to provide additional precision and prevent overflow during multiplication and accumulation.

After each matrix-vector multiplication, the accumulated values are scaled back down by the fixed-point scale factor before becoming the next PageRank vector.

## How to test

Reset the design by driving rst_n low, then release reset by driving rst_n high.

To start a PageRank calculation:
Set ui_in[0] (start) high.
Provide at least one clock cycle.
Return ui_in[0] low.
Wait for uo_out[0] (done) to become high.
Once done is high, the final PageRank values can be read one at a time.

The result address is controlled by ui_in[4:2]:
Address  Page
      0  Home
      1	 News
      2  Sports
      3  Shopping
      4  Videos
      5  Maps
Set ui_in[1] (rd_en) high while selecting the desired address.

The 11-bit rd_data value is divided across the Tiny Tapeout outputs:
  uo_out[3:1] contains rd_data[10:8].
  uio_out[7:0] contains rd_data[7:0].
The uio pins are configured as outputs by the Tiny Tapeout wrapper.

For verification, the RTL testbench should compare the six hardware results against a software reference implementation using the same fixed-point arithmetic and transition matrix.

## External hardware

No external hardware is required.

The project uses only the standard Tiny Tapeout clock, reset, input, output, and bidirectional GPIO pins.
