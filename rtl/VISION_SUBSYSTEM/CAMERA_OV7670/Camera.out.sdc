## Generated SDC file "Camera.out.sdc"

## Copyright (C) 2020  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 20.1.0 Build 711 06/05/2020 SJ Lite Edition"

## DATE    "Thu Oct 16 15:25:35 2025"

##
## DEVICE  "5CSEMA5F31C6"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {clk} -period 20.000 -waveform { 0.000 10.000 } [get_ports { CLOCK_50 }]
create_clock -name {PCLK} -period 10.000 -waveform { 0.000 5.000 } [get_ports {OV7670_PCLK}]


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {PCLK}] -rise_to [get_clocks {PCLK}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {PCLK}] -rise_to [get_clocks {PCLK}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {PCLK}] -fall_to [get_clocks {PCLK}] -setup 0.170  
set_clock_uncertainty -rise_from [get_clocks {PCLK}] -fall_to [get_clocks {PCLK}] -hold 0.060  
set_clock_uncertainty -rise_from [get_clocks {PCLK}] -rise_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {PCLK}] -fall_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {PCLK}] -rise_to [get_clocks {PCLK}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {PCLK}] -rise_to [get_clocks {PCLK}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {PCLK}] -fall_to [get_clocks {PCLK}] -setup 0.170  
set_clock_uncertainty -fall_from [get_clocks {PCLK}] -fall_to [get_clocks {PCLK}] -hold 0.060  
set_clock_uncertainty -fall_from [get_clocks {PCLK}] -rise_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {PCLK}] -fall_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -rise_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {clk}] -rise_to [get_clocks {clk}]  0.190  
set_clock_uncertainty -fall_from [get_clocks {clk}] -fall_to [get_clocks {clk}]  0.190  


#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[0]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[0]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[1]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[1]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[2]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[2]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[3]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[3]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[4]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[4]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[5]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[5]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[6]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[6]}]
set_input_delay -add_delay -max -clock [get_clocks {PCLK}]  8.500 [get_ports {OV7670_DATA[7]}]
set_input_delay -add_delay -min -clock [get_clocks {PCLK}]  2.500 [get_ports {OV7670_DATA[7]}]


#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************


