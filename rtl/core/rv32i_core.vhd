-- Integrated non-pipelined multicycle core for the minimal RV32I processor.
--
-- Supported instructions:
--   LUI, ADDI, XORI, SW, BNE and JAL
--
-- The core presents separate instruction and data interfaces so the SoC can
-- connect them to the two ports of one true dual-port block RAM. The current
-- instruction subset performs stores but does not require a data-read input.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.rv32i_pkg.all;

entity rv32i_core is
    port (
        clk_i : in std_logic;
        rst_i : in std_logic;

        instruction_addr_o : out word_t;
        instruction_data_i : in  word_t;

        data_addr_o       : out word_t;
        data_write_data_o : out word_t;
        data_write_o      : out std_logic;
        data_wstrb_o      : out byte_strobe_t;

        trap_o  : out std_logic;
        state_o : out control_state_t
    );
end entity rv32i_core;

architecture rtl of rv32i_core is

    ---------------------------------------------------------------------------
    -- Architectural and multicycle datapath registers
    ---------------------------------------------------------------------------
    signal pc_register         : word_t := RESET_PC_ADDR;
    signal instruction_register : word_t := ZERO_WORD;
    signal operand_a_register  : word_t := ZERO_WORD;
    signal operand_b_register  : word_t := ZERO_WORD;
    signal alu_result_register : word_t := ZERO_WORD;

    ---------------------------------------------------------------------------
    -- Decoded instruction information
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Register-file signals
    ---------------------------------------------------------------------------
    signal rs1_data      : word_t;
    signal rs2_data      : word_t;
    signal writeback_data : word_t;

    ---------------------------------------------------------------------------
    -- Control signals
    ---------------------------------------------------------------------------
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
    signal state      : control_state_t;

    ---------------------------------------------------------------------------
    -- Combinational datapath signals
    ---------------------------------------------------------------------------
    signal immediate_value : word_t;
    signal alu_operand_a   : word_t;
    signal alu_operand_b   : word_t;
    signal alu_result      : word_t;
    signal operands_equal  : std_logic;

    signal pc_plus_four      : word_t;
    signal pc_plus_immediate : word_t;
    signal next_pc           : word_t;

begin

    ---------------------------------------------------------------------------
    -- External instruction and data interfaces
    ---------------------------------------------------------------------------
    instruction_addr_o <= pc_register;

    -- SW uses the saved ALU result as its address and the saved rs2 value as
    -- its write data. Both remain stable throughout STATE_MEMORY_STORE.
    data_addr_o       <= alu_result_register;
    data_write_data_o <= operand_b_register;
    data_write_o      <= data_write;
    data_wstrb_o      <= data_wstrb;

    state_o <= state;
    trap_o  <= '1' when state = STATE_TRAP else '0';

    ---------------------------------------------------------------------------
    -- Instruction decoder
    ---------------------------------------------------------------------------
    decoder_inst : entity work.rv32i_decoder
        port map (
            instruction_i => instruction_register,
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

    ---------------------------------------------------------------------------
    -- Multicycle control FSM
    ---------------------------------------------------------------------------
    control_inst : entity work.rv32i_control_fsm
        port map (
            clk_i              => clk_i,
            rst_i              => rst_i,
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

    ---------------------------------------------------------------------------
    -- Register file
    ---------------------------------------------------------------------------
    register_file_inst : entity work.rv32i_register_file
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i,
            rs1_addr_i  => rs1_addr,
            rs2_addr_i  => rs2_addr,
            rd_addr_i   => rd_addr,
            rd_write_i  => reg_write,
            rd_data_i   => writeback_data,
            rs1_data_o  => rs1_data,
            rs2_data_o  => rs2_data
        );

    ---------------------------------------------------------------------------
    -- Immediate generator
    ---------------------------------------------------------------------------
    immediate_generator_inst : entity work.rv32i_immediate_generator
        port map (
            instruction_i   => instruction_register,
            immediate_sel_i => immediate_select,
            immediate_o     => immediate_value
        );

    ---------------------------------------------------------------------------
    -- ALU operand multiplexers
    ---------------------------------------------------------------------------
    alu_a_mux : process (all)
    begin
        case alu_a_select is
            when ALU_A_RS1 =>
                alu_operand_a <= operand_a_register;

            when ALU_A_PC =>
                alu_operand_a <= pc_register;

            when ALU_A_ZERO =>
                alu_operand_a <= ZERO_WORD;
        end case;
    end process alu_a_mux;

    alu_b_mux : process (all)
    begin
        case alu_b_select is
            when ALU_B_RS2 =>
                alu_operand_b <= operand_b_register;

            when ALU_B_IMMEDIATE =>
                alu_operand_b <= immediate_value;

            when ALU_B_FOUR =>
                alu_operand_b <= x"00000004";
        end case;
    end process alu_b_mux;

    alu_inst : entity work.rv32i_alu
        port map (
            operand_a_i => alu_operand_a,
            operand_b_i => alu_operand_b,
            operation_i => alu_operation,
            result_o    => alu_result,
            equal_o     => operands_equal
        );

    ---------------------------------------------------------------------------
    -- Register writeback multiplexer
    ---------------------------------------------------------------------------
    writeback_mux : process (all)
    begin
        case writeback_select is
            when WB_ALU_RESULT =>
                writeback_data <= alu_result_register;

            when WB_IMMEDIATE =>
                writeback_data <= immediate_value;

            when WB_PC_PLUS_4 =>
                writeback_data <= pc_plus_four;
        end case;
    end process writeback_mux;

    ---------------------------------------------------------------------------
    -- Next-PC logic
    ---------------------------------------------------------------------------
    pc_plus_four <= std_logic_vector(
        unsigned(pc_register) + to_unsigned(4, XLEN)
    );

    pc_plus_immediate <= std_logic_vector(
        unsigned(pc_register) + unsigned(immediate_value)
    );

    next_pc_mux : process (all)
    begin
        case next_pc_select is
            when NEXT_PC_PLUS_4 =>
                next_pc <= pc_plus_four;

            when NEXT_PC_BRANCH =>
                next_pc <= pc_plus_immediate;

            when NEXT_PC_JUMP =>
                -- During STATE_EXECUTE_JUMP the FSM selects PC and the J-type
                -- immediate as the ALU inputs, so the ALU produces the target.
                next_pc <= alu_result;
        end case;
    end process next_pc_mux;

    ---------------------------------------------------------------------------
    -- Datapath state registers
    ---------------------------------------------------------------------------
    datapath_registers : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                pc_register          <= RESET_PC_ADDR;
                instruction_register <= ZERO_WORD;
                operand_a_register   <= ZERO_WORD;
                operand_b_register   <= ZERO_WORD;
                alu_result_register  <= ZERO_WORD;
            else
                if ir_write = '1' then
                    instruction_register <= instruction_data_i;
                end if;

                if operand_write = '1' then
                    operand_a_register <= rs1_data;
                    operand_b_register <= rs2_data;
                end if;

                if alu_result_write = '1' then
                    alu_result_register <= alu_result;
                end if;

                if pc_write = '1' then
                    pc_register <= next_pc;
                end if;
            end if;
        end if;
    end process datapath_registers;
   
--   ila_inst : ila_riscv_core
--    port map (
--        clk    => clk_i,
--        probe0 => (0 => rst_i),
--        probe1 => core_instruction_addr,
--        probe2 => core_instruction_data,
--        probe3 => core_data_addr,
--        probe4 => core_data_write_data,
--        probe5 => (0 => core_data_write),
--        probe6 => core_data_wstrb,
--        probe7 => (0 => trap_o)
--    );

end architecture rtl;
