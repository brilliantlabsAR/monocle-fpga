`default_nettype none

`include "defines.v"

module mic_if (
  clk_board,
  rst,
  // Control
  en_mic,
  sync_to_video,
  // Upstream Interface
  mic_clk,
  mic_data,
  mic_ws,
  // Downstream Interface
  slow_sys_clk,
  pcm_valid,
  pcm_data
);
  
  input  wire                       clk_board;
  input  wire                       rst;
  // Control
  input  wire                       en_mic;        //Reg IF clock
  input  wire                       sync_to_video; //Reg IF clock
  // Upstream Interface
  output wire                       mic_clk;
  input  wire                       mic_data;
  output wire                       mic_ws;
  // Downstream Interface
  output wire                       slow_sys_clk;
  output wire                       pcm_valid;
  output wire [`PCM_DSIZE-1:0]      pcm_data;
  
  // Local Parameters
  
  // Internal Signals
  wire                              rst_n;
  reg  [3:0]                        data_indx;
  reg  [15:0]                       rom_data;
  
  //================================================
  // Mic/PDM Clock Gen
  //================================================
  // Divide by 20 clock divider
  mic_clk_gen i_clk_div (
    .clk_board           (clk_board      ),
    .rst                 (rst            ),
    .en                  (en_mic         ),
    .clk_2_4mhz          (slow_sys_clk   ),
    .clk_1_2mhz          (mic_clk        )
  );
  
  //================================================
  // Gowin's PDM2PCM IP
  //================================================
  assign rst_n = ~rst;
  pdm2pcm i_pdm2pcm (
    .clk                 (slow_sys_clk   ),
    .rstn                (rst_n          ),
    .ce                  (en_mic         ),
    .in_pdm_data         (mic_data       ),
    .in_pdm_sclk         (mic_clk        ),
    .out_pcm_valid       (pcm_valid      ),
    .out_pcm_sync        (               ),
  `ifdef EN_AUDIO_TEST_PAT
    .out_pcm_data        (               ) 
  `else
    .out_pcm_data        (pcm_data       ) 
  `endif
  );
  
  `ifdef EN_AUDIO_TEST_PAT
    always @(posedge slow_sys_clk) begin
      if (rst) begin
        data_indx <= 4'b0;
      end else if (pcm_valid) begin
        data_indx <= data_indx + 4'b1;
      end
    end
    
    //For 16'h501A, checksum is 16'hC717
    always @(posedge slow_sys_clk) begin
      if (rst) begin
        rom_data <= 16'h0000;
      end else begin
        case (data_indx)
          4'd0  : rom_data <= 16'h501A;
          4'd1  : rom_data <= 16'h501A;
          4'd2  : rom_data <= 16'h501A;
          4'd3  : rom_data <= 16'h501A;
          4'd4  : rom_data <= 16'h501A;
          4'd5  : rom_data <= 16'h501A;
          4'd6  : rom_data <= 16'h501A;
          4'd7  : rom_data <= 16'h501A;
          4'd8  : rom_data <= 16'h501A;
          4'd9  : rom_data <= 16'h501A;
          4'd10 : rom_data <= 16'h501A;
          4'd11 : rom_data <= 16'h501A;
          4'd12 : rom_data <= 16'h501A;
          4'd13 : rom_data <= 16'h501A;
          4'd14 : rom_data <= 16'h501A;
          4'd15 : rom_data <= 16'h501A;
        endcase
      end
    end
    
    assign pcm_data = rom_data;
  `endif
    
  assign mic_ws = 1'b0; //Select Right channel
  
endmodule
`default_nettype wire