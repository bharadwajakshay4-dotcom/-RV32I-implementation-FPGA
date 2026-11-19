-- Self-checking testbench for the minimal RV32I ALU.

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_alu is
end entity tb_rv32i_alu;

architecture sim of tb_rv32i_alu is

    signal operand_a : word_t := ZERO_WORD;
    signal operand_b : word_t := ZERO_WORD;
    signal operation : alu_operation_t := ALU_ADD;
    signal result    : word_t;
    signal equal     : std_logic;

begin

    dut : entity work.rv32i_alu
        port map (
            operand_a_i => operand_a,
            operand_b_i => operand_b,
            operation_i => operation,
            result_o    => result,
            equal_o     => equal
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- ADD: normal addition
        -----------------------------------------------------------------------
        operand_a <= x"00000005";
        operand_b <= x"00000007";
        operation <= ALU_ADD;
        wait for 1 ns;

        assert result = x"0000000C"
            report "ALU_ADD failed for 5 + 7"
            severity error;

        assert equal = '0'
            report "equal_o should be low for 5 and 7"
            severity error;

        -----------------------------------------------------------------------
        -- ADD: RV32I 32-bit wraparound
        -----------------------------------------------------------------------
        operand_a <= x"FFFFFFFF";
        operand_b <= x"00000001";
        operation <= ALU_ADD;
        wait for 1 ns;

        assert result = x"00000000"
            report "ALU_ADD failed 32-bit wraparound"
            severity error;

        -----------------------------------------------------------------------
        -- ADD: address calculation used by SW
        -----------------------------------------------------------------------
        operand_a <= x"40000000";
        operand_b <= x"00000000";
        operation <= ALU_ADD;
        wait for 1 ns;

        assert result = LED_MMIO_ADDR
            report "ALU_ADD failed LED MMIO address calculation"
            severity error;

        -----------------------------------------------------------------------
        -- XOR: operation used by XORI
        -----------------------------------------------------------------------
        operand_a <= x"AAAAAAAA";
        operand_b <= x"FFFFFFFF";
        operation <= ALU_XOR;
        wait for 1 ns;

        assert result = x"55555555"
            report "ALU_XOR failed"
            severity error;

        -----------------------------------------------------------------------
        -- PASS_B: operation used to pass the LUI immediate
        -----------------------------------------------------------------------
        operand_a <= x"DEADBEEF";
        operand_b <= x"40000000";
        operation <= ALU_PASS_B;
        wait for 1 ns;

        assert result = x"40000000"
            report "ALU_PASS_B failed"
            severity error;

        -----------------------------------------------------------------------
        -- Equality comparison used by BNE
        -----------------------------------------------------------------------
        operand_a <= x"12345678";
        operand_b <= x"12345678";
        operation <= ALU_XOR;
        wait for 1 ns;

        assert equal = '1'
            report "equal_o should be high for equal operands"
            severity error;

        operand_b <= x"12345679";
        wait for 1 ns;

        assert equal = '0'
            report "equal_o should be low for unequal operands"
            severity error;

        report "All RV32I ALU tests passed"
            severity note;

        
        wait;
    end process stimulus;

end architecture sim;
