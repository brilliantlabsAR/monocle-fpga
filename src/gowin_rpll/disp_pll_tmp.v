//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: V1.9.7.03Beta
//Part Number: GW1N-LV9MG100C6/I5
//Device: GW1N-9C
//Created Time: Sat Jan 15 14:33:14 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    disp_pll your_instance_name(
        .clkout(clkout_o), //output clkout
        .lock(lock_o), //output lock
        .clkoutp(clkoutp_o), //output clkoutp
        .clkin(clkin_i) //input clkin
    );

//--------Copy end-------------------
