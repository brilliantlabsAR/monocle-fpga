//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//GOWIN Version: GowinSynthesis V1.9.7.03Beta
//Part Number: GW1N-LV9MG100C6/I5
//Device: GW1N-9C
//Created Time: Mon Jan 17 14:54:37 2022

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	afifo_fwft_w16r32x512 your_instance_name(
		.Data(Data_i), //input [15:0] Data
		.WrReset(WrReset_i), //input WrReset
		.RdReset(RdReset_i), //input RdReset
		.WrClk(WrClk_i), //input WrClk
		.RdClk(RdClk_i), //input RdClk
		.WrEn(WrEn_i), //input WrEn
		.RdEn(RdEn_i), //input RdEn
		.Rnum(Rnum_o), //output [9:0] Rnum
		.Q(Q_o), //output [31:0] Q
		.Empty(Empty_o), //output Empty
		.Full(Full_o) //output Full
	);

//--------Copy end-------------------
