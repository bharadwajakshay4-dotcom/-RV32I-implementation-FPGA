-- Self-checking testbench for the RV32I immediate generator.

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_immediate_generator is
end entity tb_rv32i_immediate_generator;

architecture sim of tb_rv32i_immediate_generator is

    signal instruction   : word_t := ZERO_WORD;
    signal immediate_sel : immediate_select_t := IMM_I;
    signal immediate     : word_t;

begin

    dut : entity work.rv32i_immediate_generator
        port map (
            instruction_i   => instruction,
            immediate_sel_i => immediate_sel,
            immediate_o     => immediate
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- I-type: ADDI x1, x0, 123
        -----------------------------------------------------------------------
        instruction   <= x"07B00093";
        immediate_sel <= IMM_I;
        wait for 1 ns;

        assert immediate = x"0000007B"
            report "IMM_I failed for positive immediate 123"
            severity error;

        -----------------------------------------------------------------------
        -- I-type: ADDI x1, x0, -1
        -----------------------------------------------------------------------
        instruction <= x"FFF00093";
        wait for 1 ns;

        assert immediate = x"FFFFFFFF"
            report "IMM_I failed to sign-extend -1"
            severity error;

        -----------------------------------------------------------------------
        -- I-type lower limit: XORI x1, x0, -2048
        -----------------------------------------------------------------------
        instruction <= x"80004093";
        wait for 1 ns;

        assert immediate = x"FFFFF800"
            report "IMM_I failed to sign-extend -2048"
            severity error;

        -----------------------------------------------------------------------
        -- S-type: SW x2, 16(x1)
        -----------------------------------------------------------------------
        instruction   <= x"0020A823";
        immediate_sel <= IMM_S;
        wait for 1 ns;

        assert immediate = x"00000010"
            report "IMM_S failed for positive store offset 16"
            severity error;

        -----------------------------------------------------------------------
        -- S-type: SW x2, -4(x1)
        -----------------------------------------------------------------------
        instruction <= x"FE20AE23";
        wait for 1 ns;

        assert immediate = x"FFFFFFFC"
            report "IMM_S failed to sign-extend store offset -4"
            severity error;

        -----------------------------------------------------------------------
        -- B-type: BNE x1, x2, +16
        -----------------------------------------------------------------------
        instruction   <= x"00209863";
        immediate_sel <= IMM_B;
        wait for 1 ns;

        assert immediate = x"00000010"
            report "IMM_B failed for positive branch offset 16"
            severity error;

        -----------------------------------------------------------------------
        -- B-type: BNE x1, x2, -4
        -----------------------------------------------------------------------
        instruction <= x"FE209EE3";
        wait for 1 ns;

        assert immediate = x"FFFFFFFC"
            report "IMM_B failed to sign-extend branch offset -4"
            severity error;

        -----------------------------------------------------------------------
        -- U-type: LUI x5, 0x40000
        -----------------------------------------------------------------------
        instruction   <= x"400002B7";
        immediate_sel <= IMM_U;
        wait for 1 ns;

        assert immediate = x"40000000"
            report "IMM_U failed for LUI value 0x40000000"
            severity error;

        -----------------------------------------------------------------------
        -- U-type: LUI x1, 0xABCDE
        -----------------------------------------------------------------------
        instruction <= x"ABCDE0B7";
        wait for 1 ns;

        assert immediate = x"ABCDE000"
            report "IMM_U failed for LUI value 0xABCDE000"
            severity error;

        -----------------------------------------------------------------------
        -- J-type: JAL x1, +16
        -----------------------------------------------------------------------
        instruction   <= x"010000EF";
        immediate_sel <= IMM_J;
        wait for 1 ns;

        assert immediate = x"00000010"
            report "IMM_J failed for positive jump offset 16"
            severity error;

        -----------------------------------------------------------------------
        -- J-type: JAL x1, -4
        -----------------------------------------------------------------------
        instruction <= x"FFDFF0EF";
        wait for 1 ns;

        assert immediate = x"FFFFFFFC"
            report "IMM_J failed to sign-extend jump offset -4"
            severity error;

        report "All RV32I immediate-generator tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
