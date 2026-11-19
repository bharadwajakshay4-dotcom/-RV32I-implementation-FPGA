-- Combinational instruction decoder for the minimal RV32I processor.
--
-- Supported instructions:
--   LUI, ADDI, XORI, SW, BNE and JAL

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_decoder is
    port (
        instruction_i : in word_t;

        rs1_addr_o : out reg_addr_t;
        rs2_addr_o : out reg_addr_t;
        rd_addr_o  : out reg_addr_t;

        is_lui_o  : out std_logic;
        is_addi_o : out std_logic;
        is_xori_o : out std_logic;
        is_sw_o   : out std_logic;
        is_bne_o  : out std_logic;
        is_jal_o  : out std_logic;

        illegal_o : out std_logic
    );
end entity rv32i_decoder;

architecture rtl of rv32i_decoder is
begin

    ---------------------------------------------------------------------------
    -- Register-field extraction
    --
    -- These fields are always extracted. The control unit decides which fields
    -- are meaningful for the current instruction. For example, LUI and JAL do
    -- not use rs1 or rs2 even though those bit positions still exist.
    ---------------------------------------------------------------------------
    rd_addr_o  <= instruction_i(11 downto 7);
    rs1_addr_o <= instruction_i(19 downto 15);
    rs2_addr_o <= instruction_i(24 downto 20);

    ---------------------------------------------------------------------------
    -- Instruction recognition
    -- All outputs receive defaults first, preventing inferred latches. A valid
    -- instruction clears illegal_o and asserts exactly one instruction flag.
    ---------------------------------------------------------------------------
    decode_comb : process (all)
        variable opcode : opcode_t;
        variable funct3 : funct3_t;
    begin
        opcode := instruction_i(6 downto 0);
        funct3 := instruction_i(14 downto 12);

        is_lui_o  <= '0';
        is_addi_o <= '0';
        is_xori_o <= '0';
        is_sw_o   <= '0';
        is_bne_o  <= '0';
        is_jal_o  <= '0';
        illegal_o <= '1';

        case opcode is
            when OPCODE_LUI =>
                is_lui_o  <= '1';
                illegal_o <= '0';

            when OPCODE_OP_IMM =>
                case funct3 is
                    when FUNCT3_ADDI =>
                        is_addi_o <= '1';
                        illegal_o <= '0';

                    when FUNCT3_XORI =>
                        is_xori_o <= '1';
                        illegal_o <= '0';

                    when others =>
                        null;
                end case;

            when OPCODE_STORE =>
                if funct3 = FUNCT3_SW then
                    is_sw_o   <= '1';
                    illegal_o <= '0';
                end if;

            when OPCODE_BRANCH =>
                if funct3 = FUNCT3_BNE then
                    is_bne_o  <= '1';
                    illegal_o <= '0';
                end if;

            when OPCODE_JAL =>
                is_jal_o  <= '1';
                illegal_o <= '0';

            when others =>
                null;
        end case;
    end process decode_comb;

end architecture rtl;
