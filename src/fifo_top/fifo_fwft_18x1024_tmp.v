//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: GowinSynthesis V1.9.7.03Beta
//Part Number: GW1N-LV9MG100C6/I5
//Device: GW1N-9C
//Created Time: Mon Jan 17 14:56:42 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	fifo_fwft_18x1024 your_instance_name(
		.Data(Data_i), //input [17:0] Data
		.Clk(Clk_i), //input Clk
		.WrEn(WrEn_i), //input WrEn
		.RdEn(RdEn_i), //input RdEn
		.Reset(Reset_i), //input Reset
		.Wnum(Wnum_o), //output [10:0] Wnum
		.Almost_Empty(Almost_Empty_o), //output Almost_Empty
		.Almost_Full(Almost_Full_o), //output Almost_Full
		.Q(Q_o), //output [17:0] Q
		.Empty(Empty_o), //output Empty
		.Full(Full_o) //output Full
	);

//--------Copy end-------------------
