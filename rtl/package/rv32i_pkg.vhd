-- Common definitions for the minimal multicycle RV32I processor.
--
-- Initial supported instructions:
--   LUI, ADDI, XORI, SW, BNE and JAL

library ieee;
use ieee.std_logic_1164.all;

package rv32i_pkg is

    ---------------------------------------------------------------------------
    -- Basic datapath types
    ---------------------------------------------------------------------------
    constant XLEN             : positive := 32;
    constant REG_ADDR_WIDTH   : positive := 5;
    constant BRAM_ADDR_WIDTH  : positive := 10; -- 1024 x 32-bit words

    subtype word_t        is std_logic_vector(XLEN - 1 downto 0);
    subtype reg_addr_t    is std_logic_vector(REG_ADDR_WIDTH - 1 downto 0);
    subtype bram_addr_t   is std_logic_vector(BRAM_ADDR_WIDTH - 1 downto 0);
    subtype opcode_t      is std_logic_vector(6 downto 0);
    subtype funct3_t      is std_logic_vector(2 downto 0);
    subtype byte_strobe_t is std_logic_vector(3 downto 0);

    constant ZERO_WORD       : word_t        := (others => '0');
    constant WORD_WRITE      : byte_strobe_t := "1111";
    constant NO_BYTE_WRITE   : byte_strobe_t := "0000";

    ---------------------------------------------------------------------------
    -- RV32I opcode values used by the minimal processor
    ---------------------------------------------------------------------------
    constant OPCODE_LUI    : opcode_t := "0110111";
    constant OPCODE_OP_IMM : opcode_t := "0010011";
    constant OPCODE_STORE  : opcode_t := "0100011";
    constant OPCODE_BRANCH : opcode_t := "1100011";
    constant OPCODE_JAL    : opcode_t := "1101111";

    ---------------------------------------------------------------------------
    -- funct3 values. Values are interpreted together with the opcode.
    ---------------------------------------------------------------------------
    constant FUNCT3_ADDI : funct3_t := "000";
    constant FUNCT3_XORI : funct3_t := "100";
    constant FUNCT3_SW   : funct3_t := "010";
    constant FUNCT3_BNE  : funct3_t := "001";

    ---------------------------------------------------------------------------
    -- SoC memory map
    ---------------------------------------------------------------------------
    constant RESET_PC_ADDR : word_t := x"00000000";
    constant BRAM_BASE_ADDR : word_t := x"00000000";
    constant BRAM_LAST_ADDR : word_t := x"00000FFF";
    constant LED_MMIO_ADDR  : word_t := x"40000000";

    ---------------------------------------------------------------------------
    -- Datapath control types
    ---------------------------------------------------------------------------
    type alu_operation_t is (
        ALU_ADD,
        ALU_XOR,
        ALU_PASS_B
    );

    type immediate_select_t is (
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J
    );

    type alu_a_select_t is (
        ALU_A_RS1,
        ALU_A_PC,
        ALU_A_ZERO
    );

    type alu_b_select_t is (
        ALU_B_RS2,
        ALU_B_IMMEDIATE,
        ALU_B_FOUR
    );

    type writeback_select_t is (
        WB_ALU_RESULT,
        WB_IMMEDIATE,
        WB_PC_PLUS_4
    );

    type next_pc_select_t is (
        NEXT_PC_PLUS_4,
        NEXT_PC_BRANCH,
        NEXT_PC_JUMP
    );

    ---------------------------------------------------------------------------
    -- Multicycle controller states
    ---------------------------------------------------------------------------
    type control_state_t is (
        STATE_RESET,
        STATE_FETCH_REQUEST,
        STATE_FETCH_RESPONSE,
        STATE_DECODE,
        STATE_EXECUTE_LUI,
        STATE_EXECUTE_ALU_IMMEDIATE,
        STATE_WRITEBACK,
        STATE_EXECUTE_STORE_ADDRESS,
        STATE_MEMORY_STORE,
        STATE_EXECUTE_BRANCH,
        STATE_EXECUTE_JUMP,
        STATE_TRAP
    );

end package rv32i_pkg;

package body rv32i_pkg is
end package body rv32i_pkg;
