`default_nettype none

`include "defines.v"

module luma_correction (
  rst,
  clk,
  en,
  en_zoom,
  sel_zoom_mode,
  // Upstream Interface
  us_vld,
  luma_rdy,
  us_rd_data,
  // Downstream Interface
  ds_vld,
  ds_rdy,
  ds_rd_data
);
  
  // Camera Interface
  input  wire                       rst;
  input  wire                       clk;
  input  wire                       en;
  input  wire                       en_zoom;
  input  wire [1:0]                 sel_zoom_mode;
  // Upstream Interface
  input  wire                       us_vld;
  output wire                       luma_rdy;
  input  wire [`DSIZE-1:0]          us_rd_data;
  // Downstream Interface
  output wire                       ds_vld;
  input  wire                       ds_rdy;
  output wire [`DSIZE-1:0]          ds_rd_data;

  // Local Parameters
  localparam  COL_CNT_WIDTH       = 3; // Max upto 8x
  
  // Internal Signals
  wire                             en_luma_cor;
  reg  [COL_CNT_WIDTH-1:0]         col_cntr;
  wire [COL_CNT_WIDTH-1:0]         zoom_x;
  wire                             col_cnt_done;
  wire                             sel_2nd_luma;
  wire [7:0]                       y0;
  wire [7:0]                       cb;
  wire [7:0]                       y1;
  wire [7:0]                       cr;
  wire [`DSIZE-1:0]                luma_cor_data;
  
  assign en_luma_cor = en & en_zoom;
  
  // Column duplication
  always @(posedge clk) begin
    if (rst) begin
      col_cntr <= {COL_CNT_WIDTH{1'b0}};
    end else if (en_luma_cor & us_vld & ds_rdy) begin
      if (col_cnt_done) begin
        col_cntr <= {COL_CNT_WIDTH{1'b0}};
      end else begin
        col_cntr <= col_cntr + 'h1;
      end
    end
  end
  
  assign zoom_x = sel_zoom_mode == 2'b10 ? 3'b111 : //8x
                  sel_zoom_mode == 2'b01 ? 3'b011 : //4x
                                           3'b001 ; //2x
  
  assign col_cnt_done = col_cntr == zoom_x ? 1'b1 : 1'b0;
  
  // Luma component selection
  assign sel_2nd_luma = sel_zoom_mode == 2'b10 ? col_cntr[2] : //8x
                        sel_zoom_mode == 2'b01 ? col_cntr[1] : //4x
                                                 col_cntr[0] ; //2x
  
  assign y0 = us_rd_data[0+:8];
  assign cb = us_rd_data[8+:8];
  assign y1 = us_rd_data[16+:8];
  assign cr = us_rd_data[24+:8];
  
  assign luma_cor_data[0+:8]  = sel_2nd_luma ? y1 : y0;
  assign luma_cor_data[8+:8]  = cb;
  assign luma_cor_data[16+:8] = sel_2nd_luma ? y1 : y0;
  assign luma_cor_data[24+:8] = cr;
  assign luma_cor_data[`DSIZE-1:32] = us_rd_data[`DSIZE-1:32];
  
  //================================================
  // Bypass Luma Correction if zoom & luma correction are disabled
  //================================================
  assign luma_rdy   = ds_rdy;
  assign ds_vld     = us_vld;
  assign ds_rd_data = en_luma_cor ? luma_cor_data : us_rd_data;
    
endmodule
`default_nettype wire