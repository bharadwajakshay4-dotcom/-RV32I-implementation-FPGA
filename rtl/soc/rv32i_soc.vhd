-- Complete minimal RV32I SoC.
--
-- Integrates:
--   * non-pipelined multicycle RV32I core
--   * 4 KiB true dual-port block RAM
--   * data-side address interconnect
--   * two-bit LED MMIO output register

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_soc is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        led_o : out std_logic_vector(1 downto 0);

        trap_o  : out std_logic;
        state_o : out control_state_t
    );
end entity rv32i_soc;

architecture rtl of rv32i_soc is

    ---------------------------------------------------------------------------
    -- Core instruction interface
    ---------------------------------------------------------------------------
    signal core_instruction_addr : word_t;
    signal core_instruction_data : word_t;

    ---------------------------------------------------------------------------
    -- Core data interface
    ---------------------------------------------------------------------------
    signal core_data_addr       : word_t;
    signal core_data_write_data : word_t;
    signal core_data_write      : std_logic;
    signal core_data_wstrb      : byte_strobe_t;

    ---------------------------------------------------------------------------
    -- Interconnect to BRAM Port B
    ---------------------------------------------------------------------------
    signal bram_data_addr       : bram_addr_t;
    signal bram_data_write_data : word_t;
    signal bram_data_wstrb      : byte_strobe_t;
    signal bram_data_read_data  : word_t;

    ---------------------------------------------------------------------------
    -- Interconnect to LED MMIO
    ---------------------------------------------------------------------------
    signal led_write_data : word_t;
    signal led_write      : std_logic;

begin

    ---------------------------------------------------------------------------
    -- RV32I processor core
    ---------------------------------------------------------------------------
    core_inst : entity work.rv32i_core
        port map (
            clk_i              => clk_i,
            rst_i              => rst_i,
            instruction_addr_o => core_instruction_addr,
            instruction_data_i => core_instruction_data,
            data_addr_o        => core_data_addr,
            data_write_data_o  => core_data_write_data,
            data_write_o       => core_data_write,
            data_wstrb_o       => core_data_wstrb,
            trap_o             => trap_o,
            state_o            => state_o
        );

    ---------------------------------------------------------------------------
    -- Data-side address decoder
    ---------------------------------------------------------------------------
    interconnect_inst : entity work.soc_data_interconnect
        port map (
            core_addr_i       => core_data_addr,
            core_write_data_i => core_data_write_data,
            core_write_i      => core_data_write,
            core_wstrb_i      => core_data_wstrb,
            bram_addr_o       => bram_data_addr,
            bram_write_data_o => bram_data_write_data,
            bram_wstrb_o      => bram_data_wstrb,
            led_write_data_o  => led_write_data,
            led_write_o       => led_write
        );

    ---------------------------------------------------------------------------
    -- Unified instruction/data block RAM
    --
    -- The core supplies 32-bit byte addresses. BRAM Port A requires a 10-bit
    -- word address, so bits 1 downto 0 are discarded here. Port B conversion
    -- is performed by soc_data_interconnect.
    ---------------------------------------------------------------------------
    memory_inst : entity work.unified_bram
        port map (
            clk_i              => clk_i,
            instruction_addr_i => core_instruction_addr(
                BRAM_ADDR_WIDTH + 1 downto 2
            ),
            instruction_data_o => core_instruction_data,
            data_addr_i        => bram_data_addr,
            data_write_data_i  => bram_data_write_data,
            data_wstrb_i       => bram_data_wstrb,
            data_read_data_o   => bram_data_read_data
        );

    ---------------------------------------------------------------------------
    -- Memory-mapped LED output register
    ---------------------------------------------------------------------------
    led_mmio_inst : entity work.led_mmio
        port map (
            clk_i        => clk_i,
            rst_i        => rst_i,
            write_i      => led_write,
            write_data_i => led_write_data,
            led_o        => led_o
        );

    -- bram_data_read_data is intentionally unused by the current SW-only data
    -- interface. It will feed the core when load instructions are implemented.

end architecture rtl;
