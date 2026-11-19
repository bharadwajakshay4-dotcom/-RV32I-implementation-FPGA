-- Self-checking testbench for the integrated minimal RV32I core.
-- Testbench clock: 10 MHz (100 ns period).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_core is
end entity tb_rv32i_core;

architecture sim of tb_rv32i_core is

    constant CLK_PERIOD : time := 100 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal instruction_addr : word_t;
    signal instruction_data : word_t := ZERO_WORD;

    signal data_addr       : word_t;
    signal data_write_data : word_t;
    signal data_write      : std_logic;
    signal data_wstrb      : byte_strobe_t;

    signal trap  : std_logic;
    signal state : control_state_t;

    signal store_count : natural range 0 to 15 := 0;

    ---------------------------------------------------------------------------
    -- Test program
    --
    -- Address  Machine code  Instruction
    -- 0x00     400002B7      LUI  x5, 0x40000
    -- 0x04     00100313      ADDI x6, x0, 1
    -- 0x08     0062A023      SW   x6, 0(x5)       -> write 1
    -- 0x0C     00334313      XORI x6, x6, 3       -> x6 = 2
    -- 0x10     0062A023      SW   x6, 0(x5)       -> write 2
    -- 0x14     00200393      ADDI x7, x0, 2
    -- 0x18     00731463      BNE  x6, x7, +8      -> not taken
    -- 0x1C     00130313      ADDI x6, x6, 1       -> x6 = 3
    -- 0x20     0062A023      SW   x6, 0(x5)       -> write 3
    -- 0x24     00731463      BNE  x6, x7, +8      -> taken to 0x2C
    -- 0x28     0002A023      SW   x0, 0(x5)       -> must be skipped
    -- 0x2C     008000EF      JAL  x1, +8           -> x1 = 0x30, PC = 0x34
    -- 0x30     0002A023      SW   x0, 0(x5)       -> must be skipped
    -- 0x34     0012A023      SW   x1, 0(x5)       -> write link 0x30
    -- 0x38     00000000      Illegal instruction -> trap
    ---------------------------------------------------------------------------
    type instruction_memory_t is array (0 to 15) of word_t;

    constant PROGRAM_ROM : instruction_memory_t := (
        0  => x"400002B7",
        1  => x"00100313",
        2  => x"0062A023",
        3  => x"00334313",
        4  => x"0062A023",
        5  => x"00200393",
        6  => x"00731463",
        7  => x"00130313",
        8  => x"0062A023",
        9  => x"00731463",
        10 => x"0002A023",
        11 => x"008000EF",
        12 => x"0002A023",
        13 => x"0012A023",
        14 => x"00000000",
        others => x"00000000"
    );

begin

    ---------------------------------------------------------------------------
    -- Clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------------------
    dut : entity work.rv32i_core
        port map (
            clk_i              => clk,
            rst_i              => rst,
            instruction_addr_o => instruction_addr,
            instruction_data_i => instruction_data,
            data_addr_o        => data_addr,
            data_write_data_o  => data_write_data,
            data_write_o       => data_write,
            data_wstrb_o       => data_wstrb,
            trap_o             => trap,
            state_o            => state
        );

    ---------------------------------------------------------------------------
    -- Synchronous instruction-memory model
    --
    -- This models the one-clock read latency of BRAM Port A. The core's
    -- FETCH_REQUEST and FETCH_RESPONSE states are designed around this delay.
    ---------------------------------------------------------------------------
    instruction_memory : process (clk)
        variable word_index : natural;
    begin
        if rising_edge(clk) then
            word_index := to_integer(unsigned(instruction_addr(5 downto 2)));
            instruction_data <= PROGRAM_ROM(word_index);
        end if;
    end process instruction_memory;

    ---------------------------------------------------------------------------
    -- Store-transaction monitor
    --
    -- The supported subset has no load instruction, so store transactions are
    -- used as externally visible signatures of correct register execution.
    ---------------------------------------------------------------------------
    store_monitor : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '0' and data_write = '1' then
                assert data_addr = LED_MMIO_ADDR
                    report "Core wrote to an unexpected data address"
                    severity error;

                assert data_wstrb = WORD_WRITE
                    report "SW did not assert all four byte strobes"
                    severity error;

                case store_count is
                    when 0 =>
                        assert data_write_data = x"00000001"
                            report "First store did not write LED value 1"
                            severity error;

                    when 1 =>
                        assert data_write_data = x"00000002"
                            report "XORI result was not 2 in the second store"
                            severity error;

                    when 2 =>
                        assert data_write_data = x"00000003"
                            report "Non-taken BNE path did not produce value 3"
                            severity error;

                    when 3 =>
                        assert data_write_data = x"00000030"
                            report "JAL did not write return address 0x30 to x1"
                            severity error;

                    when others =>
                        assert false
                            report "Unexpected extra store transaction"
                            severity error;
                end case;

                store_count <= store_count + 1;
            end if;
        end if;
    end process store_monitor;

    ---------------------------------------------------------------------------
    -- Reset, timeout and final checks
    ---------------------------------------------------------------------------
    stimulus : process
    begin
        -- Hold the synchronous reset active for two rising edges.
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        -- The complete program should reach its deliberate illegal instruction
        -- well before this timeout.
        wait until trap = '1' for 20 us;

        assert trap = '1'
            report "Core did not reach the expected illegal-instruction trap"
            severity failure;

        wait for 1 ns;

        assert instruction_addr = x"00000038"
            report "Trap occurred at an unexpected program counter"
            severity error;

        assert store_count = 4
            report "Incorrect number of store transactions; a branch or jump failed"
            severity error;

        report "All RV32I core tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
