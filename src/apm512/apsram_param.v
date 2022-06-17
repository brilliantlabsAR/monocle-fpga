parameter DQ_WIDTH               = 8;//8,16,...
parameter PSRAM_WIDTH            = 8;//8,16
parameter Fixed_Latency_Enable   = "Fixed";//"Unfixed"
parameter RL                     = "6";//"3","4","5","6","7"
parameter Drive_Strength         = "Full";//"Full","1/2","1/4","1/8"
parameter PASR                   = "full";//bottom_1/2,bottom_1/4,bottom_1/8,none,top_1/2,top_1/4,top_1/8
parameter ADDR_WIDTH             = 26;//X8 == 25,X16 == 24 US == 26
parameter WL                     = "6";//"3","4","5","6","7"
parameter Refresh_Rate           = "4X";// "4X","1X","0.5X"
parameter Power_Down             = "None";//"None", "Half_Sleep","Deep_Power_Down"
parameter DQ_MODE                = "X8";//"X8","X16"
parameter RBX                    = "OFF";//"OFF","ON"
parameter Burst_Type             = "Word_Wrap";//"Word_Wrap","Hybrid_Wrap"
parameter Burst_Length           = "2K_Byte"; //"16_Byte","32_Byte","64_Byte","2K_Byte"
parameter LANE_WIDTH             = 1;
 
