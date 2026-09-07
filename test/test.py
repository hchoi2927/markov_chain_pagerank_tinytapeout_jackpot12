import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
dut._log.info("Starting PageRank test")

# 50 MHz clock = 20 ns period
clock = Clock(dut.clk, 20, unit="ns")
cocotb.start_soon(clock.start())

# Reset
dut.ena.value = 1
dut.ui_in.value = 0
dut.uio_in.value = 0
dut.rst_n.value = 0

await ClockCycles(dut.clk, 5)

dut.rst_n.value = 1

# Start PageRank calculation.
# ui_in[0] = start
dut.ui_in.value = 0b00000001
await ClockCycles(dut.clk, 1)

# Return start low.
dut.ui_in.value = 0

# Wait for the calculation to finish.
# Use a generous timeout so the test does not depend on
# the exact FSM cycle count.
for _ in range(2000):
    if int(dut.uo_out.value) & 0x01:
        break
    await ClockCycles(dut.clk, 1)
else:
    raise AssertionError("PageRank calculation did not finish")

dut._log.info("PageRank calculation completed")

# Read all six PageRank values.
#
# rd_en   = ui_in[1]
# rd_addr = ui_in[4:2]
#
# rd_data[10:8] -> uo_out[3:1]
# rd_data[7:0]  -> uio_out[7:0]

results = []

for addr in range(6):
    dut.ui_in.value = (addr << 2) | 0b00000010

    await ClockCycles(dut.clk, 1)

    high_bits = (int(dut.uo_out.value) >> 1) & 0x07
    low_bits = int(dut.uio_out.value)

    value = (high_bits << 8) | low_bits

    results.append(value)

dut._log.info(f"PageRank results: {results}")

# Basic sanity checks.
assert all(0 <= value <= 512 for value in results), \
    f"Invalid PageRank value(s): {results}"

# The six probabilities should approximately sum to 512.
total = sum(results)

assert abs(total - 512) <= 6, \
    f"PageRank values do not sum to approximately 512: {results}, sum={total}"

dut._log.info("PageRank test passed")
