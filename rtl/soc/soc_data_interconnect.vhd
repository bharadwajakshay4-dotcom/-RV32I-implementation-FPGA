-- Data-side address decoder for the minimal RV32I SoC.
--
-- Current address map:
--   0x00000000 - 0x00000FFF : 4 KiB unified BRAM
--   0x40000000              : LED output register
--
-- The current processor subset supports SW but no load instructions, so this
-- first interconnect routes writes only. Read-data multiplexing can be added
-- when load instructions are implemented.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32i_pkg.all;

entity soc_data_interconnect is
    port (
        -----------------------------------------------------------------------
        -- Core data interface: 32-bit byte address
        -----------------------------------------------------------------------
        core_addr_i       : in word_t;
        core_write_data_i : in word_t;
        core_write_i      : in std_logic;
        core_wstrb_i      : in byte_strobe_t;

        -----------------------------------------------------------------------
        -- Unified BRAM Port B interface: 10-bit word address
        -----------------------------------------------------------------------
        bram_addr_o       : out bram_addr_t;
        bram_write_data_o : out word_t;
        bram_wstrb_o      : out byte_strobe_t;

        -----------------------------------------------------------------------
        -- LED MMIO interface
        -----------------------------------------------------------------------
        led_write_data_o : out word_t;
        led_write_o      : out std_logic
    );
end entity soc_data_interconnect;

architecture rtl of soc_data_interconnect is
begin

    ---------------------------------------------------------------------------
    -- Address and write-data routing
    --
    -- The core uses byte addresses. Removing bits 1 downto 0 converts an
    -- aligned byte address into the BRAM's word index.
    ---------------------------------------------------------------------------
    bram_addr_o <= core_addr_i(BRAM_ADDR_WIDTH + 1 downto 2);

    bram_write_data_o <= core_write_data_i;
    led_write_data_o  <= core_write_data_i;

    ---------------------------------------------------------------------------
    -- Write destination decoder
    ---------------------------------------------------------------------------
    write_decode : process (all)
    begin
        bram_wstrb_o <= NO_BYTE_WRITE;
        led_write_o  <= '0';

        if core_write_i = '1' then
            if unsigned(core_addr_i) >= unsigned(BRAM_BASE_ADDR) and
               unsigned(core_addr_i) <= unsigned(BRAM_LAST_ADDR) then

                -- SW must be word-aligned. Suppressing a misaligned write
                -- prevents it from silently modifying the wrong BRAM word.
                if core_addr_i(1 downto 0) = "00" then
                    bram_wstrb_o <= core_wstrb_i;
                end if;

            elsif core_addr_i = LED_MMIO_ADDR then
                -- LED bits 1 downto 0 occupy byte lane zero. A transaction
                -- that does not enable that lane cannot change the LEDs.
                if core_wstrb_i(0) = '1' then
                    led_write_o <= '1';
                end if;
            end if;
        end if;
    end process write_decode;

end architecture rtl;
