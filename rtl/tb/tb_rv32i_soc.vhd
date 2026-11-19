-- Self-checking testbench for the complete minimal RV32I SoC.
-- Testbench clock: 10 MHz (100 ns period).
--
-- The BRAM IP is initialized with led_blink.coe. The hardware firmware uses a
-- long software-delay count, so this test verifies the first LED write and
-- confirms that execution enters the delay loop without trapping. A complete
-- LED toggle would require roughly one million loop iterations.

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_soc is
end entity tb_rv32i_soc;

architecture sim of tb_rv32i_soc is

    constant CLK_PERIOD : time := 100 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal led   : std_logic_vector(1 downto 0);
    signal trap  : std_logic;
    signal state : control_state_t;

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------------------
    dut : entity work.rv32i_soc
        port map (
            clk_i   => clk,
            rst_i   => rst,
            led_o   => led,
            trap_o  => trap,
            state_o => state
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- Hold the synchronous reset active for two rising clock edges.
        -----------------------------------------------------------------------
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        assert state = STATE_RESET
            report "SoC control FSM did not remain in RESET"
            severity error;

        assert led = "00"
            report "LED output was not cleared during reset"
            severity error;

        assert trap = '0'
            report "Trap was asserted during reset"
            severity error;

        wait until falling_edge(clk);
        rst <= '0';

        -----------------------------------------------------------------------
        -- The first three firmware instructions are:
        --   LUI  x5, 0x40000
        --   ADDI x6, x0, 1
        --   SW   x6, 0(x5)
        -- They must cause LED pattern 01 well before the timeout.
        -----------------------------------------------------------------------
        wait until led = "01" for 10 us;

        assert led = "01"
            report "Firmware did not write initial LED pattern 01"
            severity failure;

        assert trap = '0'
            report "Core trapped before the first LED MMIO write"
            severity error;

        -----------------------------------------------------------------------
        -- After the LED store, firmware loads x7, decrements it and executes
        -- BNE repeatedly. Reaching EXECUTE_BRANCH proves that instruction fetch
        -- continued through BRAM and entered the software-delay loop.
        -----------------------------------------------------------------------
        wait until state = STATE_EXECUTE_BRANCH for 10 us;

        assert state = STATE_EXECUTE_BRANCH
            report "Firmware did not enter the BNE software-delay loop"
            severity failure;

        assert trap = '0'
            report "Core trapped while entering the software-delay loop"
            severity error;

        -----------------------------------------------------------------------
        -- The hardware delay is intentionally much longer than this interval.
        -- The LED must retain pattern 01 while the core continues looping.
        -----------------------------------------------------------------------
        wait for 2 us;

        assert led = "01"
            report "LED changed before the software delay completed"
            severity error;

        assert trap = '0'
            report "Core trapped while executing the software-delay loop"
            severity error;

        report "All RV32I SoC tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
