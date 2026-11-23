# SNES_MiST_LC: SDRAM at 4 x clk_sys (~86 MHz)
# Clock constraints

create_clock -name "CLOCK_27" -period 37.037 [get_ports {CLOCK_27}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set sdram_clk "pll|altpll_component|auto_generated|pll1|clk[0]"
set mem_clk   "pll|altpll_component|auto_generated|pll1|clk[1]"
set sys_clk   "pll|altpll_component|auto_generated|pll1|clk[2]"

# Clock groups
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks pll|altpll_component|auto_generated|pll1|clk[*]]

# Some relaxed constrain to the VGA pins. The signals should arrive together, the delay is not really important.
set_output_delay -clock [get_clocks $sys_clk] -max 0 [get_ports {VGA_*}]
set_output_delay -clock [get_clocks $sys_clk] -min -5 [get_ports {VGA_*}]

set_multicycle_path -to {VGA_*[*]} -setup 2
set_multicycle_path -to {VGA_*[*]} -hold 1

# SDRAM delays
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min 3.5 [get_ports SDRAM_DQ[*]]

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

# SDRAM read data (CL2): driven after the SDRAM_CLK edge one cycle after the
# CAS + 1, sampled by clk_mem 3 cycles after the CAS
set_multicycle_path -from [get_clocks $sdram_clk] -to [get_clocks $mem_clk] -setup -end 2

# clk_mem (4 x clk_sys) -> clk_sys: the SDRAM controller results are read by
# clk_sys at least one clk_sys cycle after they are written (as the Calypso port)
set_multicycle_path -from [get_clocks $mem_clk] -to [get_clocks $sys_clk] -setup -start 3
set_multicycle_path -from [get_clocks $mem_clk] -to [get_clocks $sys_clk] -hold -start 2

set_false_path -to [get_ports {SDRAM_CLK}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {LED}]
set_false_path -to [get_ports {UART_TX}]
