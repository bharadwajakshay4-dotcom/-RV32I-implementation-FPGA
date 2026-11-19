-- Self-checking testbench for the RV32I register file.
-- Testbench clock: 10 MHz (100 ns period).

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

library work;
use work.rv32i_pkg.all;

entity tb_rv32i_register_file is
end entity tb_rv32i_register_file;

architecture sim of tb_rv32i_register_file is

    constant CLK_PERIOD : time := 100 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal rs1_addr : reg_addr_t := "00000";
    signal rs2_addr : reg_addr_t := "00000";
    signal rd_addr  : reg_addr_t := "00000";

    signal rd_write : std_logic := '0';
    signal rd_data  : word_t := ZERO_WORD;

    signal rs1_data : word_t;
    signal rs2_data : word_t;

begin

    ---------------------------------------------------------------------------
    -- 10 MHz clock generation
    ---------------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------------------
    dut : entity work.rv32i_register_file
        port map (
            clk_i      => clk,
            rst_i      => rst,
            rs1_addr_i => rs1_addr,
            rs2_addr_i => rs2_addr,
            rd_addr_i  => rd_addr,
            rd_write_i => rd_write,
            rd_data_i  => rd_data,
            rs1_data_o => rs1_data,
            rs2_data_o => rs2_data
        );

    stimulus : process
    begin
        -----------------------------------------------------------------------
        -- Hold reset active for two rising clock edges.
        -----------------------------------------------------------------------
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        rst <= '0';

        -----------------------------------------------------------------------
        -- Initial values and x0 behavior
        -----------------------------------------------------------------------
        rs1_addr <= "00000"; -- x0
        rs2_addr <= "00001"; -- x1
        wait for 1 ns;

        assert rs1_data = ZERO_WORD
            report "x0 did not initially read as zero"
            severity error;

        assert rs2_data = ZERO_WORD
            report "x1 did not initially read as zero"
            severity error;

        -----------------------------------------------------------------------
        -- Write 0x40000000 to x5.
        -----------------------------------------------------------------------
        rd_addr  <= "00101"; -- x5
        rd_data  <= x"40000000";
        rd_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rd_write <= '0';

        rs1_addr <= "00101";
        wait for 1 ns;

        assert rs1_data = x"40000000"
            report "Write or read of x5 failed"
            severity error;

        -----------------------------------------------------------------------
        -- Write independent values into x6 and x7.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rd_addr  <= "00110"; -- x6
        rd_data  <= x"00000001";
        rd_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        rd_write <= '0';
        wait until falling_edge(clk);
        rd_addr  <= "00111"; -- x7
        rd_data  <= x"00100000";
        rd_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rd_write <= '0';

        -- Check both asynchronous read ports simultaneously.
        rs1_addr <= "00110"; -- x6
        rs2_addr <= "00111"; -- x7
        wait for 1 ns;

        assert rs1_data = x"00000001"
            report "Read port 1 failed to read x6"
            severity error;

        assert rs2_data = x"00100000"
            report "Read port 2 failed to read x7"
            severity error;

        -----------------------------------------------------------------------
        -- Attempt to write x0. The write must be ignored.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rd_addr  <= "00000";
        rd_data  <= x"DEADBEEF";
        rd_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rd_write <= '0';

        rs1_addr <= "00000";
        wait for 1 ns;

        assert rs1_data = ZERO_WORD
            report "x0 changed after an attempted write"
            severity error;

        -----------------------------------------------------------------------
        -- Verify that rd_write = 0 prevents a write to x8.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rd_addr  <= "01000"; -- x8
        rd_data  <= x"CAFEBABE";
        rd_write <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        rs1_addr <= "01000";
        wait for 1 ns;

        assert rs1_data = ZERO_WORD
            report "x8 changed while rd_write was disabled"
            severity error;

        -----------------------------------------------------------------------
        -- Verify that reset inhibits a write to x9.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rst      <= '1';
        rd_addr  <= "01001"; -- x9
        rd_data  <= x"12345678";
        rd_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;

        rst      <= '0';
        rd_write <= '0';
        rs1_addr <= "01001";
        wait for 1 ns;

        assert rs1_data = ZERO_WORD
            report "x9 changed while reset was active"
            severity error;

        -----------------------------------------------------------------------
        -- Overwrite x5 and confirm that the new value is returned.
        -----------------------------------------------------------------------
        wait until falling_edge(clk);
        rd_addr  <= "00101"; -- x5
        rd_data  <= x"40000004";
        rd_write <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rd_write <= '0';

        rs1_addr <= "00101";
        rs2_addr <= "00110";
        wait for 1 ns;

        assert rs1_data = x"40000004"
            report "Overwriting x5 failed"
            severity error;

        assert rs2_data = x"00000001"
            report "Writing x5 unexpectedly changed x6"
            severity error;

        report "All RV32I register-file tests passed"
            severity note;

        stop;
        wait;
    end process stimulus;

end architecture sim;
