`default_nettype none

`include "defines.v"
module cam_if (
  cam_rst,
  clk_board,
  // Camera Interface
  cam_clk,
  cam_xclk,
  cam_data,
  cam_href,
  cam_vsync,
  // Control
  en_xclk,
  en_cam,
  // System Interface
  cam_vld,
  cam_rd_data,
  cam_sof,
  cam_eof
);
  
  // Camera Interface
  input  wire                       cam_rst;
  input  wire                       clk_board;
  input  wire                       cam_clk;
  output wire                       cam_xclk;
  input  wire [`CAM_DSIZE-1:0]      cam_data;
  input  wire                       cam_href;
  input  wire                       cam_vsync;
  // Internal Interface                                  
  input  wire                       en_xclk;
  input  wire                       en_cam;
  output wire                       cam_vld;
  output wire [`CAM_DSIZE-1:0]      cam_rd_data;
  output wire                       cam_sof;
  output wire                       cam_eof;
  
  localparam WHITE_R               = 8'hff;
  localparam WHITE_G               = 8'hff;
  localparam WHITE_B               = 8'hff;
  localparam BLACK_R               = 8'h00;
  localparam BLACK_G               = 8'h00;
  localparam BLACK_B               = 8'h00;
  
  reg  [`CAM_DSIZE-1:0]             cam_data_c1;
  reg                               cam_href_c1;
  reg                               cam_vsync_c1;
  reg                               cam_vsync_c2;
  
  reg                               en_cam_d1;
  reg                               en_cam_sync;

  
  reg  [`FL_WIDTH-1:0]              frm_byte_cnt_c1;
  wire [`FL_WIDTH-1:0]              exp_frm_len;
  
  wire                              vsync_re;
  reg                               lch_en_cam;
  wire [`CAM_DSIZE-1:0]             cam_data_i;
  wire [`CAM_DSIZE-1:0]             cross_data;
  reg                               href_d1;
  reg  [11:0]                       byte_cntr;
  reg  [10:0]                       line_cntr;
  reg  [1:0]                        data_cntr;
  wire [7:0]                        rgb_r_reg;
  wire [7:0]                        rgb_g_reg;
  wire [7:0]                        rgb_b_reg;
  wire [15:0]                       Y_i; 
  wire [15:0]                       Cb_i;
  wire [15:0]                       Cr_i;
  wire                              href_re;

  // Register Synchronization
  always@(posedge cam_clk) begin
    en_cam_d1   <= en_cam;
    en_cam_sync <= en_cam_d1;
  end
  
  always@(posedge cam_clk or posedge cam_rst) begin
    if (cam_rst) begin
      lch_en_cam <= 'd0;
    end else if (vsync_re) begin
      lch_en_cam <= en_cam_sync;
    end
  end
  
  // Use Registered Camera input
  always@(posedge cam_clk or posedge cam_rst) begin
    if (cam_rst) begin
      cam_data_c1  <= 'd0;
      cam_href_c1  <= 'd0;
      cam_vsync_c1 <= 'd0;
    end else begin
      cam_data_c1  <= cam_data_i;
      cam_href_c1  <= cam_href;
      cam_vsync_c1 <= cam_vsync;
    end
  end
  
  always@(posedge cam_clk or posedge cam_rst) begin
    if (cam_rst) begin
      cam_vsync_c2 <= 'd0;
    end else begin
      cam_vsync_c2 <= cam_vsync_c1;
    end
  end
  
  assign vsync_re = (!cam_vsync_c2) & cam_vsync_c1;
  
  //================================================
  // Derive sideband information
  //================================================
  // Frame Length
  always@(posedge cam_clk or posedge cam_rst) begin
    if(cam_rst | vsync_re)
      frm_byte_cnt_c1 <= {`FL_WIDTH{1'b0}};
    else if(cam_vld)
      frm_byte_cnt_c1 <= frm_byte_cnt_c1 + 23'd1;
  end
  
  //assign exp_frm_len = high_res_mode_en ? `HIGH_RES_FL-1 : `FRAME_LENGTH-1;
  assign exp_frm_len = `FRAME_LENGTH-1;

  assign cam_vld = lch_en_cam & cam_href_c1;
  assign cam_rd_data = cam_data_c1;
  assign cam_sof = cam_vld & frm_byte_cnt_c1 == 0 ? 1'b1 : 1'b0;
  assign cam_eof = cam_vld & frm_byte_cnt_c1 == exp_frm_len ? 1'b1 : 1'b0;
  
  
  assign cam_xclk = en_xclk == 1'b1 ? clk_board : 1'b0;
  
  
  
  
  
  //================================================
  //*** Camera Cross Enable (Only for debug)
  //================================================
  `ifdef EN_CAM_CROSS
  always@(posedge cam_clk) begin
    href_d1  <= cam_href;
  end
  
  assign href_re = (!href_d1) & cam_href;
  
  always @(posedge cam_clk or posedge cam_rst) begin
    if (cam_rst) begin
      byte_cntr <= 12'd0;
    end else if(cam_href) begin
      byte_cntr <= byte_cntr + 'd1;
    end else begin
      byte_cntr <= 12'd0;
    end
  end
  
  always @(posedge cam_clk or posedge cam_rst) begin
    if (cam_rst) begin
      line_cntr <= 'd0;
    end else if (href_re) begin
      line_cntr <= line_cntr + 1'b1;
    end else if (vsync_re) begin
      line_cntr <= 'd0;
    end
  end
  
  assign rgb_r_reg  = (line_cntr == 200 || (byte_cntr >= 638 && byte_cntr <= 641)) ? WHITE_R : BLACK_R;
  assign rgb_g_reg  = (line_cntr == 200 || (byte_cntr >= 638 && byte_cntr <= 641)) ? WHITE_G : BLACK_G;
  assign rgb_b_reg  = (line_cntr == 200 || (byte_cntr >= 638 && byte_cntr <= 641)) ? WHITE_B : BLACK_B;
  
  assign Y_i  = 16'd16  + (((rgb_r_reg<<6)+(rgb_r_reg<<1)+(rgb_g_reg<<7)+rgb_g_reg+(rgb_b_reg<<4)+(rgb_b_reg<<3)+rgb_b_reg)>>8);
  assign Cb_i = 16'd128 + ((-((rgb_r_reg<<5)+(rgb_r_reg<<2)+(rgb_r_reg<<1))-((rgb_g_reg<<6)+(rgb_g_reg<<3)+(rgb_g_reg<<1))+(rgb_b_reg<<7)-(rgb_b_reg<<4))>>8);
  assign Cr_i = 16'd128 + (((rgb_r_reg<<7)-(rgb_r_reg<<4)-((rgb_g_reg<<6)+(rgb_g_reg<<5)-(rgb_g_reg<<1))-((rgb_b_reg<<4)+(rgb_b_reg<<1)))>>8);
  
  always@(posedge cam_clk or posedge cam_rst) begin
    if(cam_rst) begin
      data_cntr <= 2'b0;
    end else if(cam_href) begin
      data_cntr <= data_cntr + 1;
    end else begin
      data_cntr <= 2'b0;
    end
  end
  
  assign cross_data = data_cntr == 2'b01 ? Cb_i :
                      data_cntr == 2'b11 ? Cr_i :
                                            Y_i;  

  assign cam_data_i = cross_data;

  // Camera Cross disable
  `else
  assign cam_data_i = cam_data;
  `endif
  
endmodule
`default_nettype wire