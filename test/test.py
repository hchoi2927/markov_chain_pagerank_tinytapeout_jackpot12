import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Starting PageRank test")

    # Start clock
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1

    # Start PageRank calculation
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 1)

    dut.ui_in.value = 0

    # Wait for calculation to finish
    for _ in range(2000):
        await ClockCycles(dut.clk, 1)

        if int(dut.uo_out.value) & 1:
            break
    else:
        raise AssertionError("PageRank calculation did not finish")

    dut._log.info("PageRank calculation complete")

    # Read all six PageRank values
    results = []

    for addr in range(6):
        # rd_en = 1, rd_addr = addr
        dut.ui_in.value = (1 << 1) | (addr << 2)

        await ClockCycles(dut.clk, 1)

        upper = int(dut.uo_out.value) >> 1
        upper &= 0x7

        lower = int(dut.uio_out.value) & 0xff

        value = (upper << 8) | lower
        results.append(value)

        dut._log.info(f"Page {addr}: {value}")

    # The fixed-point probabilities should sum to approximately 512.
    total = sum(results)

    dut._log.info(f"Total PageRank: {total}")

    assert abs(total - 512) <= 32, (
        f"PageRank values sum to {total}, expected approximately 512"
    )
