//Copyright (C)2014-2021 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//GOWIN Version: V1.9.7.03Beta
//Part Number: GW1N-LV9MG100C6/I5
//Device: GW1N-9C
//Created Time: Sat Jan 15 14:34:03 2022

module onchip_osc (oscout);

output oscout;

OSC osc_inst (
    .OSCOUT(oscout)
);

defparam osc_inst.FREQ_DIV = 10;
defparam osc_inst.DEVICE = "GW1N-9C";

endmodule //onchip_osc
