//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: GowinSynthesis V1.9.7.03Beta
//Part Number: GW1N-LV9MG100C6/I5
//Device: GW1N-9C
//Created Time: Mon Jan 17 14:56:24 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	dist_fifo_fwft_32x18 your_instance_name(
		.Data(Data_i), //input [17:0] Data
		.Clk(Clk_i), //input Clk
		.WrEn(WrEn_i), //input WrEn
		.RdEn(RdEn_i), //input RdEn
		.Reset(Reset_i), //input Reset
		.Wnum(Wnum_o), //output [5:0] Wnum
		.Q(Q_o), //output [17:0] Q
		.Empty(Empty_o), //output Empty
		.Full(Full_o) //output Full
	);

//--------Copy end-------------------
