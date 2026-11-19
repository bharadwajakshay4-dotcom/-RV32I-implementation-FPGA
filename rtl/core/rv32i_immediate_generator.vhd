-- Immediate generator for the minimal multicycle RV32I processor.
--
-- Supported immediate encodings:
--   I-type : ADDI and XORI
--   S-type : SW
--   B-type : BNE
--   U-type : LUI
--   J-type : JAL

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_immediate_generator is
    port (
        instruction_i   : in  word_t;
        immediate_sel_i : in  immediate_select_t;

        immediate_o : out word_t
    );
end entity rv32i_immediate_generator;

architecture rtl of rv32i_immediate_generator is
begin

    immediate_comb : process (all)
    begin
        case immediate_sel_i is
            when IMM_I =>
                -- imm[11:0] = instruction[31:20]
                immediate_o <= std_logic_vector(
                    resize(signed(instruction_i(31 downto 20)), XLEN)
                );

            when IMM_S =>
                -- imm[11:5] = instruction[31:25]
                -- imm[4:0]  = instruction[11:7]
                immediate_o <= std_logic_vector(
                    resize(
                        signed(
                            instruction_i(31 downto 25) &
                            instruction_i(11 downto 7)
                        ),
                        XLEN
                    )
                );

            when IMM_B =>
                -- imm[12]   = instruction[31]
                -- imm[11]   = instruction[7]
                -- imm[10:5] = instruction[30:25]
                -- imm[4:1]  = instruction[11:8]
                -- imm[0]    = 0 (branch offsets are two-byte aligned)
                immediate_o <= std_logic_vector(
                    resize(
                        signed(
                            instruction_i(31) &
                            instruction_i(7) &
                            instruction_i(30 downto 25) &
                            instruction_i(11 downto 8) &
                            '0'
                        ),
                        XLEN
                    )
                );

            when IMM_U =>
                -- imm[31:12] = instruction[31:12]
                -- imm[11:0]  = 0
                immediate_o <= instruction_i(31 downto 12) & x"000";

            when IMM_J =>
                -- imm[20]    = instruction[31]
                -- imm[19:12] = instruction[19:12]
                -- imm[11]    = instruction[20]
                -- imm[10:1]  = instruction[30:21]
                -- imm[0]     = 0 (jump offsets are two-byte aligned)
                immediate_o <= std_logic_vector(
                    resize(
                        signed(
                            instruction_i(31) &
                            instruction_i(19 downto 12) &
                            instruction_i(20) &
                            instruction_i(30 downto 21) &
                            '0'
                        ),
                        XLEN
                    )
                );
        end case;
    end process immediate_comb;

end architecture rtl;
