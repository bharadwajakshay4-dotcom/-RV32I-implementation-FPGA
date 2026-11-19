-- Combinational ALU for the minimal multicycle RV32I processor.
--
-- Supported operations:
--   ALU_ADD    : address calculation and ADDI
--   ALU_XOR    : XORI
--   ALU_PASS_B : pass an immediate value, used by LUI

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_alu is
    port (
        operand_a_i : in  word_t;
        operand_b_i : in  word_t;
        operation_i : in  alu_operation_t;

        result_o : out word_t;
        equal_o  : out std_logic
    );
end entity rv32i_alu;

architecture rtl of rv32i_alu is
begin

    -- The equality comparison is independent of the selected ALU operation.
    -- The branch controller uses equal_o = '0' to take a BNE branch.
    equal_o <= '1' when operand_a_i = operand_b_i else '0';

    alu_comb : process (all)
    begin
        case operation_i is
            when ALU_ADD =>
                -- RV32I arithmetic wraps naturally at 32 bits.
                result_o <= std_logic_vector(
                    unsigned(operand_a_i) + unsigned(operand_b_i)
                );

            when ALU_XOR =>
                result_o <= operand_a_i xor operand_b_i;

            when ALU_PASS_B =>
                result_o <= operand_b_i;
        end case;
    end process alu_comb;

end architecture rtl;
