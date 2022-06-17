//Copyright (C)2014-2021 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.7.01 Beta
//Created Time: 2021-02-06 16:33:37

create_clock -name clk_24mhz -period 41.667 -waveform {0 20.834} [get_ports {clk_24mhz}]

// Timing Check at 100Mhz, Actual is 50Mhz
create_clock -name sys_clk -period 10 -waveform {0 5} [get_nets {sys_clk}]
//create_clock -name sys_clk -period 20 -waveform {0 10} [get_nets {sys_clk}]

// Timing Check at 200Mhz, Actual is 100Mhz
create_clock -name clk_x2 -period 5 -waveform {0 2.5} [get_nets {i_psram_memory_interface_top/u_apsram_top/clk_x2}]
//create_clock -name clk_x2 -period 10 -waveform {0 5} [get_nets {i_psram_memory_interface_top/u_apsram_top/clk_x2}]

// Timing Check at 50Mhz, Actual is 42Mhz
create_clock -name cam_clk -period 20 -waveform {0 10} [get_ports {cam_clk}]
//create_clock -name cam_clk -period 23.80 -waveform {0 11.9} [get_ports {cam_clk}]


// Timing Check at 4Mhz, Actual is 2Mhz
create_clock -name sclk_stable -period 250 -waveform {0 125} [get_nets {i_spi_slave/sclk_stable}]
//create_clock -name sclk_stable -period 500 -waveform {0 250} [get_nets {i_spi_slave/sclk_stable}]


set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {sys_clk}] -to [get_clocks {cam_clk}]
set_false_path -from [get_clocks {clk_24mhz}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {clk_24mhz}] -to [get_clocks {clk_x2}]

set_false_path -from [all_clocks] -to [get_regs {i_rst_sync/disp_rst_sync_0_s0 i_rst_sync/disp_rst_sync_1_s0 i_rst_sync/sys_rst_sync_0_s0 i_rst_sync/sys_rst_sync_1_s0 i_reg_if/rst_sw_s0}] 
//set_false_path -from [all_clocks] -to [get_regs {i_rst_sync/sys_rst_sync_0_s0 i_rst_sync/sys_rst_sync_1_s0 i_reg_if/rst_sw_s0}] 

