-- Self-checking testbench for the minimal SoC data interconnect.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_soc_data_interconnect is
end entity tb_soc_data_interconnect;

architecture sim of tb_soc_data_interconnect is

    signal core_addr       : word_t := ZERO_WORD;
    signal core_write_data : word_t := ZERO_WORD;
    signal core_write      : std_logic := '0';
    signal core_wstrb      : byte_strobe_t := NO_BYTE_WRITE;

    signal bram_addr       : bram_addr_t;
    signal bram_write_data : word_t;
    signal bram_wstrb      : byte_strobe_t;

    signal led_write_data : word_t;
    signal led_write      : std_logic;

begin

    dut : entity work.soc_data_interconnect
        port map (
            core_addr_i       => core_addr,
            core_write_data_i => core_write_data,
            core_write_i      => core_write,
            core_wstrb_i      => core_wstrb,
            bram_addr_o       => bram_addr,
            bram_write_data_o => bram_write_data,
            bram_wstrb_o      => bram_wstrb,
            led_write_data_o  => led_write_data,
            led_write_o       => led_write
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- No transaction: both destinations must remain disabled.
        -----------------------------------------------------------------------
        core_addr       <= ZERO_WORD;
        core_write_data <= x"12345678";
        core_write      <= '0';
        core_wstrb      <= WORD_WRITE;
        wait for 1 ns;

        assert bram_wstrb = NO_BYTE_WRITE and led_write = '0'
            report "A destination was enabled while core_write was low"
            severity error;

        -----------------------------------------------------------------------
        -- First BRAM word: byte address 0 maps to word address 0.
        -----------------------------------------------------------------------
        core_addr       <= x"00000000";
        core_write_data <= x"DEADBEEF";
        core_write      <= '1';
        core_wstrb      <= WORD_WRITE;
        wait for 1 ns;

        assert bram_addr = std_logic_vector(to_unsigned(0, BRAM_ADDR_WIDTH))
            report "BRAM byte address 0 did not map to word address 0"
            severity error;

        assert bram_write_data = x"DEADBEEF" and
               bram_wstrb = WORD_WRITE and led_write = '0'
            report "First BRAM-word write was routed incorrectly"
            severity error;

        -----------------------------------------------------------------------
        -- Byte address 4 maps to BRAM word address 1. Partial byte strobes are
        -- forwarded unchanged for an aligned BRAM transaction.
        -----------------------------------------------------------------------
        core_addr       <= x"00000004";
        core_write_data <= x"AABBCCDD";
        core_wstrb      <= "0101";
        wait for 1 ns;

        assert bram_addr = std_logic_vector(to_unsigned(1, BRAM_ADDR_WIDTH))
            report "BRAM byte address 4 did not map to word address 1"
            severity error;

        assert bram_write_data = x"AABBCCDD" and
               bram_wstrb = "0101" and led_write = '0'
            report "BRAM partial-write strobes were not forwarded"
            severity error;

        -----------------------------------------------------------------------
        -- Last aligned word in the 4 KiB BRAM range: byte address 0xFFC maps
        -- to word address 1023 (all ten address bits high).
        -----------------------------------------------------------------------
        core_addr       <= x"00000FFC";
        core_write_data <= x"CAFEBABE";
        core_wstrb      <= WORD_WRITE;
        wait for 1 ns;

        assert bram_addr = std_logic_vector(
            to_unsigned(1023, BRAM_ADDR_WIDTH)
        )
            report "Last BRAM byte address did not map to word address 1023"
            severity error;

        assert bram_wstrb = WORD_WRITE and led_write = '0'
            report "Last aligned BRAM write was not routed to BRAM only"
            severity error;

        -----------------------------------------------------------------------
        -- Misaligned SW inside the BRAM range must be suppressed.
        -----------------------------------------------------------------------
        core_addr  <= x"00000002";
        core_wstrb <= WORD_WRITE;
        wait for 1 ns;

        assert bram_wstrb = NO_BYTE_WRITE and led_write = '0'
            report "Misaligned BRAM write was not suppressed"
            severity error;

        -----------------------------------------------------------------------
        -- 0x00000FFF is the final byte in the BRAM range, but it is not a
        -- legal word-aligned SW address and must therefore be suppressed.
        -----------------------------------------------------------------------
        core_addr <= BRAM_LAST_ADDR;
        wait for 1 ns;

        assert bram_wstrb = NO_BYTE_WRITE and led_write = '0'
            report "Misaligned write at BRAM_LAST_ADDR was not suppressed"
            severity error;

        -----------------------------------------------------------------------
        -- First address beyond BRAM must not select either destination.
        -----------------------------------------------------------------------
        core_addr <= x"00001000";
        wait for 1 ns;

        assert bram_wstrb = NO_BYTE_WRITE and led_write = '0'
            report "Out-of-range BRAM address enabled a destination"
            severity error;

        -----------------------------------------------------------------------
        -- LED MMIO write: byte lane zero is enabled. BRAM must remain disabled.
        -----------------------------------------------------------------------
        core_addr       <= LED_MMIO_ADDR;
        core_write_data <= x"00000002";
        core_wstrb      <= WORD_WRITE;
        wait for 1 ns;

        assert led_write = '1' and led_write_data = x"00000002"
            report "LED MMIO write was not routed correctly"
            severity error;

        assert bram_wstrb = NO_BYTE_WRITE
            report "LED MMIO write also enabled BRAM"
            severity error;

        -----------------------------------------------------------------------
        -- LED register occupies byte lane zero. A write without strobe bit 0
        -- must not modify it.
        -----------------------------------------------------------------------
        core_wstrb <= "1110";
        wait for 1 ns;

        assert led_write = '0' and bram_wstrb = NO_BYTE_WRITE
            report "LED write occurred without byte lane zero enabled"
            severity error;

        -----------------------------------------------------------------------
        -- An arbitrary unmapped address must select neither destination.
        -----------------------------------------------------------------------
        core_addr  <= x"20000000";
        core_wstrb <= WORD_WRITE;
        wait for 1 ns;

        assert bram_wstrb = NO_BYTE_WRITE and led_write = '0'
            report "Unmapped address enabled a write destination"
            severity error;

        -----------------------------------------------------------------------
        -- Even a valid LED address must not write when core_write is low.
        -----------------------------------------------------------------------
        core_addr  <= LED_MMIO_ADDR;
        core_write <= '0';
        wait for 1 ns;

        assert bram_wstrb = NO_BYTE_WRITE and led_write = '0'
            report "Disabled LED transaction generated a write"
            severity error;

        report "All SoC data-interconnect tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
