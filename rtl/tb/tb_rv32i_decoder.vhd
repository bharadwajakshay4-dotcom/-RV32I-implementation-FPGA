-- Self-checking testbench for the minimal RV32I instruction decoder.

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_decoder is
end entity tb_rv32i_decoder;

architecture sim of tb_rv32i_decoder is

    signal instruction : word_t := ZERO_WORD;

    signal rs1_addr : reg_addr_t;
    signal rs2_addr : reg_addr_t;
    signal rd_addr  : reg_addr_t;

    signal is_lui  : std_logic;
    signal is_addi : std_logic;
    signal is_xori : std_logic;
    signal is_sw   : std_logic;
    signal is_bne  : std_logic;
    signal is_jal  : std_logic;
    signal illegal : std_logic;

begin

    dut : entity work.rv32i_decoder
        port map (
            instruction_i => instruction,
            rs1_addr_o     => rs1_addr,
            rs2_addr_o     => rs2_addr,
            rd_addr_o      => rd_addr,
            is_lui_o       => is_lui,
            is_addi_o      => is_addi,
            is_xori_o      => is_xori,
            is_sw_o        => is_sw,
            is_bne_o       => is_bne,
            is_jal_o       => is_jal,
            illegal_o      => illegal
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- LUI x5, 0x40000
        -----------------------------------------------------------------------
        instruction <= x"400002B7";
        wait for 1 ns;

        assert is_lui = '1' and illegal = '0'
            report "Failed to decode LUI"
            severity error;

        assert rd_addr = "00101"
            report "Incorrect rd field for LUI"
            severity error;

        assert is_addi = '0' and is_xori = '0' and is_sw = '0' and
               is_bne = '0' and is_jal = '0'
            report "More than one instruction flag asserted for LUI"
            severity error;

        -----------------------------------------------------------------------
        -- ADDI x6, x0, 1
        -----------------------------------------------------------------------
        instruction <= x"00100313";
        wait for 1 ns;

        assert is_addi = '1' and illegal = '0'
            report "Failed to decode ADDI"
            severity error;

        assert rs1_addr = "00000" and rd_addr = "00110"
            report "Incorrect register fields for ADDI"
            severity error;

        assert is_lui = '0' and is_xori = '0' and is_sw = '0' and
               is_bne = '0' and is_jal = '0'
            report "More than one instruction flag asserted for ADDI"
            severity error;

        -----------------------------------------------------------------------
        -- XORI x6, x6, 3
        -----------------------------------------------------------------------
        instruction <= x"00334313";
        wait for 1 ns;

        assert is_xori = '1' and illegal = '0'
            report "Failed to decode XORI"
            severity error;

        assert rs1_addr = "00110" and rd_addr = "00110"
            report "Incorrect register fields for XORI"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_sw = '0' and
               is_bne = '0' and is_jal = '0'
            report "More than one instruction flag asserted for XORI"
            severity error;

        -----------------------------------------------------------------------
        -- SW x6, 0(x5)
        -----------------------------------------------------------------------
        instruction <= x"0062A023";
        wait for 1 ns;

        assert is_sw = '1' and illegal = '0'
            report "Failed to decode SW"
            severity error;

        assert rs1_addr = "00101" and rs2_addr = "00110"
            report "Incorrect register fields for SW"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_bne = '0' and is_jal = '0'
            report "More than one instruction flag asserted for SW"
            severity error;

        -----------------------------------------------------------------------
        -- BNE x1, x2, +16
        -----------------------------------------------------------------------
        instruction <= x"00209863";
        wait for 1 ns;

        assert is_bne = '1' and illegal = '0'
            report "Failed to decode BNE"
            severity error;

        assert rs1_addr = "00001" and rs2_addr = "00010"
            report "Incorrect register fields for BNE"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_sw = '0' and is_jal = '0'
            report "More than one instruction flag asserted for BNE"
            severity error;

        -----------------------------------------------------------------------
        -- JAL x1, +16
        -----------------------------------------------------------------------
        instruction <= x"010000EF";
        wait for 1 ns;

        assert is_jal = '1' and illegal = '0'
            report "Failed to decode JAL"
            severity error;

        assert rd_addr = "00001"
            report "Incorrect rd field for JAL"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_sw = '0' and is_bne = '0'
            report "More than one instruction flag asserted for JAL"
            severity error;

        -----------------------------------------------------------------------
        -- Unsupported R-type ADD x3, x1, x2
        -----------------------------------------------------------------------
        instruction <= x"002081B3";
        wait for 1 ns;

        assert illegal = '1'
            report "Unsupported ADD was not marked illegal"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_sw = '0' and is_bne = '0' and is_jal = '0'
            report "Instruction flag asserted for unsupported ADD"
            severity error;

        -----------------------------------------------------------------------
        -- Valid OP-IMM opcode but unsupported funct3: ORI x1, x1, 3
        -----------------------------------------------------------------------
        instruction <= x"0030E093";
        wait for 1 ns;

        assert illegal = '1'
            report "Unsupported OP-IMM funct3 was not marked illegal"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_sw = '0' and is_bne = '0' and is_jal = '0'
            report "Instruction flag asserted for unsupported ORI"
            severity error;

        -----------------------------------------------------------------------
        -- Valid STORE opcode but unsupported funct3: SB x2, 0(x1)
        -----------------------------------------------------------------------
        instruction <= x"00208023";
        wait for 1 ns;

        assert illegal = '1'
            report "Unsupported STORE funct3 was not marked illegal"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_sw = '0' and is_bne = '0' and is_jal = '0'
            report "Instruction flag asserted for unsupported SB"
            severity error;

        -----------------------------------------------------------------------
        -- Valid BRANCH opcode but unsupported funct3: BEQ x1, x2, +16
        -----------------------------------------------------------------------
        instruction <= x"00208863";
        wait for 1 ns;

        assert illegal = '1'
            report "Unsupported BRANCH funct3 was not marked illegal"
            severity error;

        assert is_lui = '0' and is_addi = '0' and is_xori = '0' and
               is_sw = '0' and is_bne = '0' and is_jal = '0'
            report "Instruction flag asserted for unsupported BEQ"
            severity error;

        report "All RV32I decoder tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
