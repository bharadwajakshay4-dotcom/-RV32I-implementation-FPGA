-- Self-checking testbench for the minimal RV32I multicycle control FSM.
-- Testbench clock: 10 MHz (100 ns period).

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_control_fsm is
end entity tb_rv32i_control_fsm;

architecture sim of tb_rv32i_control_fsm is

    constant CLK_PERIOD : time := 100 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal is_lui  : std_logic := '0';
    signal is_addi : std_logic := '0';
    signal is_xori : std_logic := '0';
    signal is_sw   : std_logic := '0';
    signal is_bne  : std_logic := '0';
    signal is_jal  : std_logic := '0';
    signal illegal : std_logic := '0';

    signal operands_equal : std_logic := '1';

    signal ir_write         : std_logic;
    signal operand_write    : std_logic;
    signal alu_result_write : std_logic;
    signal pc_write         : std_logic;
    signal reg_write        : std_logic;

    signal alu_a_select     : alu_a_select_t;
    signal alu_b_select     : alu_b_select_t;
    signal alu_operation    : alu_operation_t;
    signal immediate_select : immediate_select_t;
    signal writeback_select : writeback_select_t;
    signal next_pc_select   : next_pc_select_t;

    signal data_write : std_logic;
    signal data_wstrb : byte_strobe_t;

    signal state : control_state_t;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.rv32i_control_fsm
        port map (
            clk_i              => clk,
            rst_i              => rst,
            is_lui_i           => is_lui,
            is_addi_i          => is_addi,
            is_xori_i          => is_xori,
            is_sw_i            => is_sw,
            is_bne_i           => is_bne,
            is_jal_i           => is_jal,
            illegal_i          => illegal,
            operands_equal_i   => operands_equal,
            ir_write_o         => ir_write,
            operand_write_o    => operand_write,
            alu_result_write_o => alu_result_write,
            pc_write_o         => pc_write,
            reg_write_o        => reg_write,
            alu_a_select_o     => alu_a_select,
            alu_b_select_o     => alu_b_select,
            alu_operation_o    => alu_operation,
            immediate_select_o => immediate_select,
            writeback_select_o => writeback_select,
            next_pc_select_o   => next_pc_select,
            data_write_o       => data_write,
            data_wstrb_o       => data_wstrb,
            state_o            => state
        );

    stimulus : process

        procedure advance_and_check (
            constant expected_state : in control_state_t;
            constant failure_text   : in string
        ) is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;

            assert state = expected_state
                report failure_text
                severity error;
        end procedure advance_and_check;

        procedure clear_instruction_inputs is
        begin
            is_lui  <= '0';
            is_addi <= '0';
            is_xori <= '0';
            is_sw   <= '0';
            is_bne  <= '0';
            is_jal  <= '0';
            illegal <= '0';
        end procedure clear_instruction_inputs;

    begin
        -----------------------------------------------------------------------
        -- Reset and initial fetch sequence
        -----------------------------------------------------------------------
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        assert state = STATE_RESET
            report "FSM did not remain in RESET while reset was active"
            severity error;

        assert ir_write = '0' and operand_write = '0' and
               alu_result_write = '0' and pc_write = '0' and
               reg_write = '0' and data_write = '0'
            report "A write enable was active during RESET"
            severity error;

        wait until falling_edge(clk);
        rst <= '0';

        advance_and_check(STATE_FETCH_REQUEST,
                          "RESET did not transition to FETCH_REQUEST");

        assert ir_write = '0' and pc_write = '0' and reg_write = '0' and
               data_write = '0'
            report "A write enable was active during FETCH_REQUEST"
            severity error;

        advance_and_check(STATE_FETCH_RESPONSE,
                          "FETCH_REQUEST did not transition to FETCH_RESPONSE");

        assert ir_write = '1'
            report "IR write was not asserted during FETCH_RESPONSE"
            severity error;

        advance_and_check(STATE_DECODE,
                          "FETCH_RESPONSE did not transition to DECODE");

        assert operand_write = '1'
            report "Operand write was not asserted during DECODE"
            severity error;

        -----------------------------------------------------------------------
        -- LUI path
        -----------------------------------------------------------------------
        is_lui <= '1';

        advance_and_check(STATE_EXECUTE_LUI,
                          "LUI did not enter EXECUTE_LUI");

        assert alu_result_write = '1' and
               alu_a_select = ALU_A_ZERO and
               alu_b_select = ALU_B_IMMEDIATE and
               alu_operation = ALU_PASS_B and
               immediate_select = IMM_U
            report "Incorrect control outputs during EXECUTE_LUI"
            severity error;

        advance_and_check(STATE_WRITEBACK,
                          "EXECUTE_LUI did not transition to WRITEBACK");

        assert reg_write = '1' and pc_write = '1' and
               writeback_select = WB_ALU_RESULT and
               next_pc_select = NEXT_PC_PLUS_4
            report "Incorrect LUI writeback controls"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_FETCH_REQUEST,
                          "LUI writeback did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- ADDI path
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "ADDI fetch did not reach FETCH_RESPONSE");
        assert ir_write = '1'
            report "IR write missing during ADDI fetch"
            severity error;

        advance_and_check(STATE_DECODE,
                          "ADDI fetch did not reach DECODE");
        is_addi <= '1';

        advance_and_check(STATE_EXECUTE_ALU_IMMEDIATE,
                          "ADDI did not enter EXECUTE_ALU_IMMEDIATE");

        assert alu_result_write = '1' and
               alu_a_select = ALU_A_RS1 and
               alu_b_select = ALU_B_IMMEDIATE and
               alu_operation = ALU_ADD and
               immediate_select = IMM_I
            report "Incorrect ADDI execute controls"
            severity error;

        advance_and_check(STATE_WRITEBACK,
                          "ADDI execute did not transition to WRITEBACK");

        assert reg_write = '1' and pc_write = '1' and
               writeback_select = WB_ALU_RESULT and
               next_pc_select = NEXT_PC_PLUS_4
            report "Incorrect ADDI writeback controls"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_FETCH_REQUEST,
                          "ADDI writeback did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- XORI path
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "XORI fetch did not reach FETCH_RESPONSE");
        advance_and_check(STATE_DECODE,
                          "XORI fetch did not reach DECODE");
        is_xori <= '1';

        advance_and_check(STATE_EXECUTE_ALU_IMMEDIATE,
                          "XORI did not enter EXECUTE_ALU_IMMEDIATE");

        assert alu_result_write = '1' and
               alu_a_select = ALU_A_RS1 and
               alu_b_select = ALU_B_IMMEDIATE and
               alu_operation = ALU_XOR and
               immediate_select = IMM_I
            report "Incorrect XORI execute controls"
            severity error;

        advance_and_check(STATE_WRITEBACK,
                          "XORI execute did not transition to WRITEBACK");

        assert reg_write = '1' and pc_write = '1'
            report "Incorrect XORI writeback enables"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_FETCH_REQUEST,
                          "XORI writeback did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- SW path
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "SW fetch did not reach FETCH_RESPONSE");
        advance_and_check(STATE_DECODE,
                          "SW fetch did not reach DECODE");
        is_sw <= '1';

        advance_and_check(STATE_EXECUTE_STORE_ADDRESS,
                          "SW did not enter EXECUTE_STORE_ADDRESS");

        assert alu_result_write = '1' and
               alu_a_select = ALU_A_RS1 and
               alu_b_select = ALU_B_IMMEDIATE and
               alu_operation = ALU_ADD and
               immediate_select = IMM_S
            report "Incorrect SW address-calculation controls"
            severity error;

        advance_and_check(STATE_MEMORY_STORE,
                          "SW address state did not transition to MEMORY_STORE");

        assert data_write = '1' and data_wstrb = WORD_WRITE and
               pc_write = '1' and next_pc_select = NEXT_PC_PLUS_4 and
               reg_write = '0'
            report "Incorrect MEMORY_STORE controls"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_FETCH_REQUEST,
                          "MEMORY_STORE did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- BNE taken path: operands are different
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "Taken BNE fetch did not reach FETCH_RESPONSE");
        advance_and_check(STATE_DECODE,
                          "Taken BNE fetch did not reach DECODE");
        is_bne         <= '1';
        operands_equal <= '0';

        advance_and_check(STATE_EXECUTE_BRANCH,
                          "BNE did not enter EXECUTE_BRANCH");

        assert pc_write = '1' and
               next_pc_select = NEXT_PC_BRANCH and
               immediate_select = IMM_B and
               alu_a_select = ALU_A_RS1 and
               alu_b_select = ALU_B_RS2 and
               reg_write = '0' and data_write = '0'
            report "Incorrect controls for taken BNE"
            severity error;

        clear_instruction_inputs;
        operands_equal <= '1';
        advance_and_check(STATE_FETCH_REQUEST,
                          "Taken BNE did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- BNE not-taken path: operands are equal
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "Non-taken BNE fetch did not reach FETCH_RESPONSE");
        advance_and_check(STATE_DECODE,
                          "Non-taken BNE fetch did not reach DECODE");
        is_bne         <= '1';
        operands_equal <= '1';

        advance_and_check(STATE_EXECUTE_BRANCH,
                          "Non-taken BNE did not enter EXECUTE_BRANCH");

        assert pc_write = '1' and
               next_pc_select = NEXT_PC_PLUS_4 and
               immediate_select = IMM_B and
               reg_write = '0' and data_write = '0'
            report "Incorrect controls for non-taken BNE"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_FETCH_REQUEST,
                          "Non-taken BNE did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- JAL path
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "JAL fetch did not reach FETCH_RESPONSE");
        advance_and_check(STATE_DECODE,
                          "JAL fetch did not reach DECODE");
        is_jal <= '1';

        advance_and_check(STATE_EXECUTE_JUMP,
                          "JAL did not enter EXECUTE_JUMP");

        assert reg_write = '1' and pc_write = '1' and
               writeback_select = WB_PC_PLUS_4 and
               next_pc_select = NEXT_PC_JUMP and
               immediate_select = IMM_J and
               alu_a_select = ALU_A_PC and
               alu_b_select = ALU_B_IMMEDIATE
            report "Incorrect JAL controls"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_FETCH_REQUEST,
                          "JAL did not return to FETCH_REQUEST");

        -----------------------------------------------------------------------
        -- Illegal instruction and trap persistence
        -----------------------------------------------------------------------
        advance_and_check(STATE_FETCH_RESPONSE,
                          "Illegal-instruction fetch did not reach FETCH_RESPONSE");
        advance_and_check(STATE_DECODE,
                          "Illegal-instruction fetch did not reach DECODE");
        illegal <= '1';

        advance_and_check(STATE_TRAP,
                          "Illegal instruction did not enter TRAP");

        assert ir_write = '0' and operand_write = '0' and
               alu_result_write = '0' and pc_write = '0' and
               reg_write = '0' and data_write = '0' and
               data_wstrb = NO_BYTE_WRITE
            report "A state-changing control was active in TRAP"
            severity error;

        clear_instruction_inputs;
        advance_and_check(STATE_TRAP,
                          "TRAP did not remain trapped without reset");

        -----------------------------------------------------------------------
        -- Reset recovery from TRAP
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rst <= '1';

        advance_and_check(STATE_RESET,
                          "Reset did not recover the FSM from TRAP");

        wait until falling_edge(clk);
        rst <= '0';

        advance_and_check(STATE_FETCH_REQUEST,
                          "FSM did not restart fetching after trap reset");

        report "All RV32I control-FSM tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
