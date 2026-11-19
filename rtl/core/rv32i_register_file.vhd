-- Register file for the minimal multicycle RV32I processor.
--
-- Structure:
--   32 registers x 32 bits
--   two asynchronous read ports
--   one synchronous write port
--   register x0 is permanently zero

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_register_file is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        rs1_addr_i : in reg_addr_t;
        rs2_addr_i : in reg_addr_t;
        rd_addr_i  : in reg_addr_t;

        rd_write_i : in std_logic;
        rd_data_i  : in word_t;

        rs1_data_o : out word_t;
        rs2_data_o : out word_t
    );
end entity rv32i_register_file;

architecture rtl of rv32i_register_file is

    type register_array_t is array (0 to 31) of word_t;

    -- Initial values provide deterministic FPGA power-up and simulation.
    -- A processor reset does not need to clear the RISC-V general-purpose
    -- registers; software initializes every register it uses.
    signal registers : register_array_t := (others => ZERO_WORD);

begin

    ---------------------------------------------------------------------------
    -- Asynchronous read ports
    -- x0 is selected explicitly so it always reads as zero, independently of
    -- the value stored in registers(0).
    ---------------------------------------------------------------------------
    rs1_data_o <= ZERO_WORD when rs1_addr_i = "00000" else
                  registers(to_integer(unsigned(rs1_addr_i)));

    rs2_data_o <= ZERO_WORD when rs2_addr_i = "00000" else
                  registers(to_integer(unsigned(rs2_addr_i)));

    ---------------------------------------------------------------------------
    -- Synchronous write port
    -- Writes are disabled during reset and writes addressed to x0 are ignored.
    ---------------------------------------------------------------------------
    write_port : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' and rd_write_i = '1' and rd_addr_i /= "00000" then
                registers(to_integer(unsigned(rd_addr_i))) <= rd_data_i;
            end if;
        end if;
    end process write_port;

end architecture rtl;
