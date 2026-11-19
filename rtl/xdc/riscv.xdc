# 25 MHz PL clock
set_property PACKAGE_PIN C3 [get_ports board_clk_25mhz]
set_property IOSTANDARD LVCMOS18 [get_ports board_clk_25mhz]
create_clock -period 40.000 -name board_clk [get_ports board_clk_25mhz]

# KR260 carrier-card user LEDs
set_property PACKAGE_PIN F8 [get_ports uf1_led]
set_property PACKAGE_PIN E8 [get_ports uf2_led]
set_property IOSTANDARD LVCMOS18 [get_ports {uf1_led uf2_led}]
set_property DRIVE 4 [get_ports {uf1_led uf2_led}]
set_property SLEW SLOW [get_ports {uf1_led uf2_led}]