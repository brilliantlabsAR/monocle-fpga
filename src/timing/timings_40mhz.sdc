//Copyright (C)2014-2022 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.05 
//Created Time: 2022-11-09 19:47:14
create_clock -name spi_clk -period 100 -waveform {0 50} [get_ports {SCLK}]
create_clock -name cam_clk -period 21.8 -waveform {0 10.8} [get_ports {cam_clk}]
create_clock -name clk_board -period 40 -waveform {0 20} [get_nets {clk_board}]
create_clock -name sys_clk -period 25 -waveform {0 12.5} [get_nets {sys_clk}]
set_input_delay -clock cam_clk 0 [get_ports {cam_href cam_vsync cam_data[7] cam_data[6] cam_data[5] cam_data[4] cam_data[3] cam_data[2] cam_data[1] cam_data[0]}]
set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {sys_clk}] 
set_false_path -from [get_clocks {sys_clk}] -to [get_clocks {cam_clk}] 
set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {clk_board}] 
set_false_path -from [get_clocks {clk_board}] -to [get_clocks {cam_clk}] 
set_false_path -from [get_clocks {cam_clk}] -to [get_clocks {spi_clk}]

set_false_path -from [all_clocks] -to [get_regs {i_rst_sync/disp_rst_sync_0_s0 i_rst_sync/disp_rst_sync_1_s0 i_rst_sync/sys_rst_sync_0_s0 i_rst_sync/sys_rst_sync_1_s0 i_reg_if/rst_sw_s0}] 
