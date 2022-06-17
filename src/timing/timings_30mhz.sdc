//Copyright (C)2014-2021 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.7.01 Beta
//Created Time: 2021-02-06 16:33:37

// 24MHz-Board Clock
create_clock -name clk_24mhz -period 41.667 -waveform {0 20.834} [get_ports {clk_24mhz}]

//create_generated_clock -name clk_pdm_1_2mhz -source [get_ports {clk_24mhz}] -master_clock clk_24mhz -divide_by 20 -multiply_by 1 -duty_cycle 50 [get_ports {mic_clk}]
create_generated_clock -name clk_2_4mhz -source [get_ports {clk_24mhz}] -master_clock clk_24mhz -divide_by 10 -multiply_by 1 -duty_cycle 50 [get_nets {i_mic_if/clk_2_4mhz_*}]
create_generated_clock -name clk_1_2mhz -source [get_ports {clk_24mhz}] -master_clock clk_24mhz -divide_by 20 -multiply_by 1 -duty_cycle 50 [get_regs {i_mic_if/i_clk_div/clk_1_2mhz_s1}]


// 30Mhz-Memory Controller
create_clock -name sys_clk -period 33.333 -waveform {0 16.665} [get_nets {sys_clk}]

// 60Mhz-Memory Clock
create_clock -name clk_x2 -period 16.666 -waveform {0 8.333} [get_nets {i_psram_memory_interface_top/u_apsram_top/clk_x2}]

// 42Mhz-Camera Clock
create_clock -name cam_clk -period 23.80 -waveform {0 11.9} [get_ports {cam_clk}]

// 2Mhz-SPI Clock
create_clock -name sclk_stable -period 500 -waveform {0 250} [get_nets {i_spi_slave/sclk_stable}]


set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {sys_clk}] -to [get_clocks {cam_clk}]
set_false_path -from [get_clocks {clk_24mhz}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {clk_24mhz}] -to [get_clocks {clk_x2}]

set_false_path -from [all_clocks] -to [get_regs {i_rst_sync/disp_rst_sync_0_s0 i_rst_sync/disp_rst_sync_1_s0 i_rst_sync/sys_rst_sync_0_s0 i_rst_sync/sys_rst_sync_1_s0 i_reg_if/rst_sw_s0}] 

