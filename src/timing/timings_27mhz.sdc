//Copyright (C)2014-2021 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.7.01 Beta
//Created Time: 2021-02-06 16:33:37

// 24MHz-Board Clock
create_clock -name clk_24mhz -period 41.667 -waveform {0 20.834} [get_ports {clk_24mhz}]

// 27Mhz-Memory Controller
create_clock -name sys_clk -period 37.037 -waveform {0 18.5185} [get_nets {sys_clk}]

// 54Mhz-Memory Clock
create_clock -name clk_x2 -period 18.518 -waveform {0 9.259} [get_nets {i_psram_memory_interface_top/u_apsram_top/clk_x2}]

// 42Mhz-Camera Clock
create_clock -name cam_clk -period 23.80 -waveform {0 11.9} [get_ports {cam_clk}]

// 2Mhz-SPI Clock
create_clock -name sclk_stable -period 500 -waveform {0 250} [get_nets {i_spi_slave/sclk_stable}]


set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {sys_clk}] -to [get_clocks {cam_clk}]
set_false_path -from [get_clocks {clk_24mhz}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {clk_24mhz}] -to [get_clocks {clk_x2}]

set_false_path -from [all_clocks] -to [get_regs {i_rst_sync/disp_rst_sync_0_s0 i_rst_sync/disp_rst_sync_1_s0 i_rst_sync/sys_rst_sync_0_s0 i_rst_sync/sys_rst_sync_1_s0 i_reg_if/rst_sw_s0}] 

