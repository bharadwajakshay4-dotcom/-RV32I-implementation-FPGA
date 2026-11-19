-- Self-checking testbench for the LED MMIO output register.
-- Testbench clock: 10 MHz (100 ns period).

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_led_mmio is
end entity tb_led_mmio;

architecture sim of tb_led_mmio is

    constant CLK_PERIOD : time := 100 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal write_enable : std_logic := '0';
    signal write_data   : word_t := ZERO_WORD;
    signal led          : std_logic_vector(1 downto 0);

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------------------
    dut : entity work.led_mmio
        port map (
            clk_i        => clk,
            rst_i        => rst,
            write_i      => write_enable,
            write_data_i => write_data,
            led_o        => led
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- Reset must turn both LEDs off.
        -----------------------------------------------------------------------
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "00"
            report "LED register was not cleared by reset"
            severity error;

        wait until falling_edge(clk);
        rst <= '0';

        -----------------------------------------------------------------------
        -- Write pattern 01: UF1 on, UF2 off.
        -----------------------------------------------------------------------
        write_enable <= '1';
        write_data   <= x"00000001";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "01"
            report "LED register failed to capture pattern 01"
            severity error;

        -----------------------------------------------------------------------
        -- With write disabled, changing write_data must not affect the LEDs.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        write_enable <= '0';
        write_data   <= x"FFFFFFFF";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "01"
            report "LED register changed while write_enable was low"
            severity error;

        -----------------------------------------------------------------------
        -- Write pattern 10: UF1 off, UF2 on.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        write_enable <= '1';
        write_data   <= x"FFFFFFFE";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "10"
            report "LED register failed to capture pattern 10"
            severity error;

        -----------------------------------------------------------------------
        -- Write pattern 11: both LEDs on. Upper data bits must be ignored.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        write_data <= x"FFFFFFFF";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "11"
            report "LED register failed to capture pattern 11"
            severity error;

        -----------------------------------------------------------------------
        -- Write pattern 00: both LEDs off.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        write_data <= x"FFFFFFFC";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "00"
            report "LED register failed to capture pattern 00"
            severity error;

        -----------------------------------------------------------------------
        -- Reset has priority over a simultaneous write.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rst          <= '1';
        write_enable <= '1';
        write_data   <= x"00000003";
        wait until rising_edge(clk);
        wait for 1 ns;

        assert led = "00"
            report "Reset did not take priority over an LED write"
            severity error;

        report "All LED MMIO tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
