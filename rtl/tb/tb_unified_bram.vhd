-- Self-checking testbench for unified_bram and the blk_ram IP.
-- Testbench clock: 10 MHz (100 ns period).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_unified_bram is
end entity tb_unified_bram;

architecture sim of tb_unified_bram is

    constant CLK_PERIOD : time := 100 ns;

    signal clk : std_logic := '0';

    signal instruction_addr : bram_addr_t := (others => '0');
    signal instruction_data : word_t;

    signal data_addr       : bram_addr_t := (others => '0');
    signal data_write_data : word_t := ZERO_WORD;
    signal data_wstrb      : byte_strobe_t := NO_BYTE_WRITE;
    signal data_read_data  : word_t;

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------------------
    dut : entity work.unified_bram
        port map (
            clk_i              => clk,
            instruction_addr_i => instruction_addr,
            instruction_data_o => instruction_data,
            data_addr_i        => data_addr,
            data_write_data_i  => data_write_data,
            data_wstrb_i       => data_wstrb,
            data_read_data_o   => data_read_data
        );

    stimulus : process

        -----------------------------------------------------------------------
        -- Apply a word address before a rising edge and check that Port A data
        -- is available immediately after that edge. This verifies the intended
        -- one-clock Block Memory Generator read latency.
        -----------------------------------------------------------------------
        procedure check_instruction (
            constant word_address : in natural;
            constant expected     : in word_t;
            constant description  : in string
        ) is
        begin
            wait until falling_edge(clk);
            instruction_addr <= std_logic_vector(
                to_unsigned(word_address, BRAM_ADDR_WIDTH)
            );

            wait until rising_edge(clk);
            wait for 1 ns;

            assert instruction_data = expected
                report description
                severity error;
        end procedure check_instruction;

    begin
        -----------------------------------------------------------------------
        -- Port A: initialized RISC-V program from led_blink.coe
        -----------------------------------------------------------------------
        check_instruction(0, x"400002B7",
                          "Incorrect instruction at BRAM word 0: LUI x5");

        check_instruction(1, x"00100313",
                          "Incorrect instruction at BRAM word 1: ADDI x6");

        check_instruction(2, x"0062A023",
                          "Incorrect instruction at BRAM word 2: SW x6");

        check_instruction(3, x"001003B7",
                          "Incorrect instruction at BRAM word 3: LUI x7");

        check_instruction(4, x"FFF38393",
                          "Incorrect instruction at BRAM word 4: ADDI x7, -1");

        check_instruction(5, x"FE039EE3",
                          "Incorrect instruction at BRAM word 5: BNE delay");

        check_instruction(6, x"00334313",
                          "Incorrect instruction at BRAM word 6: XORI x6");

        check_instruction(7, x"FEDFF06F",
                          "Incorrect instruction at BRAM word 7: JAL loop");

        -----------------------------------------------------------------------
        -- Port A: first unused location must be filled with zero.
        -----------------------------------------------------------------------
        check_instruction(8, ZERO_WORD,
                          "Unused BRAM word 8 was not initialized to zero");

        -----------------------------------------------------------------------
        -- Port B: full 32-bit write at unused word address 100.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        data_addr <= std_logic_vector(to_unsigned(100, BRAM_ADDR_WIDTH));
        data_write_data <= x"DEADBEEF";
        data_wstrb <= WORD_WRITE;

        wait until rising_edge(clk);
        wait for 1 ns;

        -- Disable writes and perform a synchronous read of the same word.
        wait until falling_edge(clk);
        data_wstrb <= NO_BYTE_WRITE;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_read_data = x"DEADBEEF"
            report "Port B full-word write/read failed"
            severity error;

        -----------------------------------------------------------------------
        -- Port B: update only byte lane 1 (bits 15 downto 8).
        --
        -- Before: DE AD BE EF
        -- Write:  -- -- AA -- with strobe 0010
        -- After:  DE AD AA EF
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        data_write_data <= x"0000AA00";
        data_wstrb <= "0010";

        wait until rising_edge(clk);
        wait for 1 ns;

        wait until falling_edge(clk);
        data_wstrb <= NO_BYTE_WRITE;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert data_read_data = x"DEADAAEF"
            report "Port B byte-write enable test failed"
            severity error;

        report "All unified BRAM tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
