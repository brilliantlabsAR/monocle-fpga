//Copyright (C)2014-2021 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.7.01 Beta
//Created Time: 2021-02-06 16:33:37

// 25MHz-Board Clock
create_clock -name clk_board -period 40.000 -waveform {0 20.000} [get_nets {clk_board}]

//create_generated_clock -name clk_pdm_1_2mhz -source [get_ports {clk_24mhz}] -master_clock clk_24mhz -divide_by 20 -multiply_by 1 -duty_cycle 50 [get_ports {mic_clk}]
//create_generated_clock -name clk_2_4mhz -source [get_ports {clk_24mhz}] -master_clock clk_24mhz -divide_by 10 -multiply_by 1 -duty_cycle 50 [get_nets {i_mic_if/clk_2_4mhz_*}]
//create_generated_clock -name clk_1_2mhz -source [get_ports {clk_24mhz}] -master_clock clk_24mhz -divide_by 20 -multiply_by 1 -duty_cycle 50 [get_regs {i_mic_if/i_clk_div/clk_1_2mhz}]


// 40Mhz-Memory Controller
create_clock -name sys_clk -period 25 -waveform {0 12.5} [get_nets {sys_clk}]

// 80Mhz-Memory Clock
//create_clock -name clk_x2 -period 12.5 -waveform {0 6.25} [get_nets {i_psram_memory_interface_top/u_apsram_top/clk_x2}]

// 42Mhz-Camera Clock
create_clock -name cam_clk -period 23.80 -waveform {0 11.9} [get_ports {cam_clk}]

// 2Mhz-SPI Clock
//create_clock -name sclk_stable -period 500 -waveform {0 250} [get_nets {i_spi_slave/sclk_stable}]


set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {sys_clk}]
set_false_path -from [get_clocks {sys_clk}] -to [get_clocks {cam_clk}]

set_false_path -from [all_clocks] -to [get_regs {i_rst_sync/disp_rst_sync_0_s0 i_rst_sync/disp_rst_sync_1_s0 i_rst_sync/sys_rst_sync_0_s0 i_rst_sync/sys_rst_sync_1_s0 i_reg_if/rst_sw_s0}] 

