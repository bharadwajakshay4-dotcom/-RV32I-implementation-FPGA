-- Memory-mapped LED output register for the minimal RV32I SoC.
--
-- Address decoding is performed by soc_data_interconnect. When write_i is
-- asserted, bits 1 downto 0 of write_data_i become the two LED outputs:
--   bit 0 -> UF1
--   bit 1 -> UF2

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.rv32i_pkg.all;

entity led_mmio is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        write_i      : in std_logic;
        write_data_i : in word_t;

        led_o : out std_logic_vector(1 downto 0)
    );
end entity led_mmio;

architecture rtl of led_mmio is

    signal led_register : std_logic_vector(1 downto 0) := "00";

begin

    led_o <= led_register;

    led_register_process : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                led_register <= "00";
            elsif write_i = '1' then
                led_register <= write_data_i(1 downto 0);
            end if;
        end if;
    end process led_register_process;

end architecture rtl;
