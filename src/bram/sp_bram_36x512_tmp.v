//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: V1.9.7.03Beta
//Part Number: GW1N-LV9MG100C6/I5
//Device: GW1N-9C
//Created Time: Mon Jan 17 14:50:50 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    sp_bram_36x512 your_instance_name(
        .dout(dout_o), //output [35:0] dout
        .clka(clka_i), //input clka
        .cea(cea_i), //input cea
        .reseta(reseta_i), //input reseta
        .clkb(clkb_i), //input clkb
        .ceb(ceb_i), //input ceb
        .resetb(resetb_i), //input resetb
        .oce(oce_i), //input oce
        .ada(ada_i), //input [8:0] ada
        .din(din_i), //input [35:0] din
        .adb(adb_i) //input [8:0] adb
    );

//--------Copy end-------------------
