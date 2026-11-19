-- Multicycle control FSM for the minimal RV32I processor.
--
-- Supported instructions:
--   LUI, ADDI, XORI, SW, BNE and JAL

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_control_fsm is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        is_lui_i  : in std_logic;
        is_addi_i : in std_logic;
        is_xori_i : in std_logic;
        is_sw_i   : in std_logic;
        is_bne_i  : in std_logic;
        is_jal_i  : in std_logic;
        illegal_i : in std_logic;

        operands_equal_i : in std_logic;

        ir_write_o         : out std_logic;
        operand_write_o    : out std_logic;
        alu_result_write_o : out std_logic;
        pc_write_o         : out std_logic;
        reg_write_o        : out std_logic;

        alu_a_select_o     : out alu_a_select_t;
        alu_b_select_o     : out alu_b_select_t;
        alu_operation_o    : out alu_operation_t;
        immediate_select_o : out immediate_select_t;
        writeback_select_o : out writeback_select_t;
        next_pc_select_o   : out next_pc_select_t;

        data_write_o : out std_logic;
        data_wstrb_o : out byte_strobe_t;

        state_o : out control_state_t
    );
end entity rv32i_control_fsm;

architecture rtl of rv32i_control_fsm is

    signal current_state : control_state_t := STATE_RESET;
    signal next_state    : control_state_t := STATE_RESET;

begin

    ---------------------------------------------------------------------------
    -- State register
    -- The processor uses an active-high synchronous reset.
    ---------------------------------------------------------------------------
    state_register : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                current_state <= STATE_RESET;
            else
                current_state <= next_state;
            end if;
        end if;
    end process state_register;

    state_o <= current_state;

    ---------------------------------------------------------------------------
    -- Next-state logic
    ---------------------------------------------------------------------------
    next_state_comb : process (all)
    begin
        -- Remaining in the current state is the safe default. Every normal
        -- state below explicitly selects its next state.
        next_state <= current_state;

        case current_state is
            when STATE_RESET =>
                next_state <= STATE_FETCH_REQUEST;

            when STATE_FETCH_REQUEST =>
                next_state <= STATE_FETCH_RESPONSE;

            when STATE_FETCH_RESPONSE =>
                next_state <= STATE_DECODE;

            when STATE_DECODE =>
                if illegal_i = '1' then
                    next_state <= STATE_TRAP;
                elsif is_lui_i = '1' then
                    next_state <= STATE_EXECUTE_LUI;
                elsif is_addi_i = '1' or is_xori_i = '1' then
                    next_state <= STATE_EXECUTE_ALU_IMMEDIATE;
                elsif is_sw_i = '1' then
                    next_state <= STATE_EXECUTE_STORE_ADDRESS;
                elsif is_bne_i = '1' then
                    next_state <= STATE_EXECUTE_BRANCH;
                elsif is_jal_i = '1' then
                    next_state <= STATE_EXECUTE_JUMP;
                else
                    next_state <= STATE_TRAP;
                end if;

            when STATE_EXECUTE_LUI =>
                next_state <= STATE_WRITEBACK;

            when STATE_EXECUTE_ALU_IMMEDIATE =>
                next_state <= STATE_WRITEBACK;

            when STATE_WRITEBACK =>
                next_state <= STATE_FETCH_REQUEST;

            when STATE_EXECUTE_STORE_ADDRESS =>
                next_state <= STATE_MEMORY_STORE;

            when STATE_MEMORY_STORE =>
                next_state <= STATE_FETCH_REQUEST;

            when STATE_EXECUTE_BRANCH =>
                next_state <= STATE_FETCH_REQUEST;

            when STATE_EXECUTE_JUMP =>
                next_state <= STATE_FETCH_REQUEST;

            when STATE_TRAP =>
                next_state <= STATE_TRAP;
        end case;
    end process next_state_comb;

    ---------------------------------------------------------------------------
    -- Moore-style output logic
    -- All state-changing enables default to zero. Multiplexer and operation
    -- controls receive harmless defaults that are ignored unless an associated
    -- write enable is asserted.
    ---------------------------------------------------------------------------
    output_comb : process (all)
    begin
        ir_write_o         <= '0';
        operand_write_o    <= '0';
        alu_result_write_o <= '0';
        pc_write_o         <= '0';
        reg_write_o        <= '0';

        alu_a_select_o     <= ALU_A_RS1;
        alu_b_select_o     <= ALU_B_RS2;
        alu_operation_o    <= ALU_ADD;
        immediate_select_o <= IMM_I;
        writeback_select_o <= WB_ALU_RESULT;
        next_pc_select_o   <= NEXT_PC_PLUS_4;

        data_write_o <= '0';
        data_wstrb_o <= NO_BYTE_WRITE;

        case current_state is
            when STATE_RESET =>
                null;

            when STATE_FETCH_REQUEST =>
                -- The current PC is continuously connected to BRAM Port A.
                -- This state allows one clock for the synchronous BRAM read.
                null;

            when STATE_FETCH_RESPONSE =>
                -- Capture the instruction returned by BRAM Port A.
                ir_write_o <= '1';

            when STATE_DECODE =>
                -- Capture register-file outputs into the A and B registers.
                operand_write_o <= '1';

            when STATE_EXECUTE_LUI =>
                alu_a_select_o     <= ALU_A_ZERO;
                alu_b_select_o     <= ALU_B_IMMEDIATE;
                alu_operation_o    <= ALU_PASS_B;
                immediate_select_o <= IMM_U;
                alu_result_write_o <= '1';

            when STATE_EXECUTE_ALU_IMMEDIATE =>
                alu_a_select_o     <= ALU_A_RS1;
                alu_b_select_o     <= ALU_B_IMMEDIATE;
                immediate_select_o <= IMM_I;
                alu_result_write_o <= '1';

                if is_xori_i = '1' then
                    alu_operation_o <= ALU_XOR;
                else
                    alu_operation_o <= ALU_ADD;
                end if;

            when STATE_WRITEBACK =>
                writeback_select_o <= WB_ALU_RESULT;
                reg_write_o        <= '1';
                next_pc_select_o   <= NEXT_PC_PLUS_4;
                pc_write_o         <= '1';

            when STATE_EXECUTE_STORE_ADDRESS =>
                alu_a_select_o     <= ALU_A_RS1;
                alu_b_select_o     <= ALU_B_IMMEDIATE;
                alu_operation_o    <= ALU_ADD;
                immediate_select_o <= IMM_S;
                alu_result_write_o <= '1';

            when STATE_MEMORY_STORE =>
                data_write_o     <= '1';
                data_wstrb_o     <= WORD_WRITE;
                next_pc_select_o <= NEXT_PC_PLUS_4;
                pc_write_o       <= '1';

            when STATE_EXECUTE_BRANCH =>
                alu_a_select_o     <= ALU_A_RS1;
                alu_b_select_o     <= ALU_B_RS2;
                alu_operation_o    <= ALU_XOR;
                immediate_select_o <= IMM_B;
                pc_write_o         <= '1';

                if operands_equal_i = '0' then
                    next_pc_select_o <= NEXT_PC_BRANCH;
                else
                    next_pc_select_o <= NEXT_PC_PLUS_4;
                end if;

            when STATE_EXECUTE_JUMP =>
                alu_a_select_o     <= ALU_A_PC;
                alu_b_select_o     <= ALU_B_IMMEDIATE;
                alu_operation_o    <= ALU_ADD;
                immediate_select_o <= IMM_J;
                writeback_select_o <= WB_PC_PLUS_4;
                reg_write_o        <= '1';
                next_pc_select_o   <= NEXT_PC_JUMP;
                pc_write_o         <= '1';

            when STATE_TRAP =>
                -- No architectural state changes until reset.
                null;
        end case;
    end process output_comb;

end architecture rtl;
