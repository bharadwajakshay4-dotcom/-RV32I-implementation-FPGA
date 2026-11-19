-- FPGA top level for the minimal RV32I SoC on the KR260 carrier card.
--
-- The external 25 MHz clock is converted to 10 MHz by clk_wiz_0. The
-- processor remains in reset until the MMCM has locked and reset has been
-- synchronously released in the 10 MHz clock domain.

library ieee;
use ieee.std_logic_1164.all;

entity rv32i_fpga_top is
    port (
        board_clk_25mhz : in  std_logic;
        uf1_led          : out std_logic;
        uf2_led          : out std_logic
    );
end entity rv32i_fpga_top;

architecture rtl of rv32i_fpga_top is

    ---------------------------------------------------------------------------
    -- Vivado Clocking Wizard: 25 MHz input, 10 MHz output.
    ---------------------------------------------------------------------------
    component clk_wiz_0 is
        port (
            clk_out1 : out std_logic;
            reset    : in  std_logic;
            locked   : out std_logic;
            clk_in1  : in  std_logic
        );
    end component;

    signal clk_10mhz   : std_logic;
    signal clock_locked : std_logic;

    -- Asynchronously asserted when the MMCM is not locked and synchronously
    -- deasserted after two rising edges of the generated 10 MHz clock.
    signal reset_pipe : std_logic_vector(1 downto 0) := (others => '1');
    signal soc_reset  : std_logic;

    signal soc_led : std_logic_vector(1 downto 0);

begin

    clock_generator : clk_wiz_0
        port map (
            clk_out1 => clk_10mhz,
            reset    => '0',
            locked   => clock_locked,
            clk_in1  => board_clk_25mhz
        );

    reset_release : process (clk_10mhz, clock_locked)
    begin
        if clock_locked = '0' then
            reset_pipe <= (others => '1');
        elsif rising_edge(clk_10mhz) then
            reset_pipe <= reset_pipe(0) & '0';
        end if;
    end process reset_release;

    soc_reset <= reset_pipe(1);

    soc_inst : entity work.rv32i_soc
        port map (
            clk_i   => clk_10mhz,
            rst_i   => soc_reset,
            led_o   => soc_led,
            trap_o  => open,
            state_o => open
        );

    -- The KR260 UF1 and UF2 carrier-card LEDs are active high.
    uf1_led <= soc_led(0);
    uf2_led <= soc_led(1);

end architecture rtl;
