SPDX-FileCopyrightText: © 2024 Tiny Tapeout
SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
dut._log.info("Start")

# 50 MHz clock = 20 ns period
cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

# Reset
dut._log.info("Reset")
dut.ena.value = 1
dut.ui_in.value = 0
dut.uio_in.value = 0
dut.rst_n.value = 0

await ClockCycles(dut.clk, 5)

dut.rst_n.value = 1

# Start PageRank calculation
dut._log.info("Starting PageRank calculation")

dut.ui_in.value = 0b00000001
await ClockCycles(dut.clk, 1)

# Return start low
dut.ui_in.value = 0

# Wait for calculation to complete
for _ in range(1000):
    if dut.uo_out.value & 0x01:
        break
    await ClockCycles(dut.clk, 1)
else:
    raise AssertionError("PageRank calculation did not complete")

dut._log.info("PageRank calculation complete")
