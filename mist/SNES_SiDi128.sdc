#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.1.4 Build 182 03/12/2014 SJ Full Version
#
#************************************************************

# Copyright (C) 1991-2014 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "CLOCK_50" -period 20 [get_ports {CLOCK_50}]
create_clock -name {SPI_SCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

set sdram_clk "pll|altpll_component|auto_generated|pll1|clk[0]"
set mem_clk   "pll|altpll_component|auto_generated|pll1|clk[1]"
set sys_clk   "pll|altpll_component|auto_generated|pll1|clk[2]"
set sdram2_clk "pll_sdram2|altpll_component|auto_generated|pll1|clk[0]"


# Clock groups
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks pll|altpll_component|auto_generated|pll1|clk[*]]
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks pll_sdram2|altpll_component|auto_generated|pll1|clk[*]]

# SDRAM delays
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4 [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min 3.5 [get_ports SDRAM_DQ[*]]

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_multicycle_path -from [get_clocks $sdram_clk] -to [get_clocks $mem_clk] -setup -end 2

set_input_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -max 6.4 [get_ports SDRAM2_DQ[*]]
set_input_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -min 3.5 [get_ports SDRAM2_DQ[*]]

set_output_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -max 1.5 [get_ports {SDRAM2_D* SDRAM2_A* SDRAM2_BA* SDRAM2_n* SDRAM2_CKE}]
set_output_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -min -0.8 [get_ports {SDRAM2_D* SDRAM2_A* SDRAM2_BA* SDRAM2_n* SDRAM2_CKE}]


set_multicycle_path -from [get_clocks $sdram2_clk] -to [get_clocks $sys_clk] -setup -start 2
set_multicycle_path -from [get_clocks $sdram2_clk] -to [get_clocks $sys_clk] -hold -start 1

set_multicycle_path -from [get_clocks $sys_clk] -to [get_clocks $sdram2_clk] -setup -end 2
set_multicycle_path -from [get_clocks $sys_clk] -to [get_clocks $sdram2_clk] -hold -end 1

set_multicycle_path -from [get_clocks $mem_clk] -to [get_clocks $sys_clk] -setup -start 3
set_multicycle_path -from [get_clocks $mem_clk] -to [get_clocks $sys_clk] -hold -start 2


set_false_path -to [get_ports {SDRAM_CLK}]
set_false_path -to [get_ports {SDRAM2_CLK}]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]
set_false_path -to [get_ports {LED}]