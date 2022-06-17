`default_nettype none

`include "defines.v"

module color_bar (
  clk,
  rst,
  en_cam,
  hs,
  vs,
  de,
  data
);
  input  wire                       clk;
  input  wire                       rst;
  input  wire                       en_cam;
  output wire                       hs;
  output wire                       vs;
  output wire                       de;
  output wire [7:0]                 data;
  
/*********Video timing parameter definition******************************************/
//parameter H_ACTIVE = 16'd1280;  //Effective line length (number of pixel clock cycles)
//parameter H_FP = 16'd110;       //Shoulder length
//parameter H_SYNC = 16'd40;      //Line synchronization length
//parameter H_BP = 16'd220;       //Shoulder length after synchronization
//parameter V_ACTIVE = 16'd720;   //Effective field length (number of rows)
//parameter V_FP   = 16'd5;        //Field sync front shoulder length
//parameter V_SYNC  = 16'd5;      //Field sync length
//parameter V_BP  = 16'd20;       //Shoulder length after field sync

//parameter H_ACTIVE = 16'd1920;
//parameter H_FP = 16'd88;
//parameter H_SYNC = 16'd44;
//parameter H_BP = 16'd148; 
//parameter V_ACTIVE = 16'd1080;
//parameter V_FP   = 16'd4;
//parameter V_SYNC  = 16'd5;
//parameter V_BP  = 16'd36;

  parameter H_ACTIVE              = 16'd1280;
  parameter H_FP                  = 16'd66;
  parameter H_SYNC                = 16'd50;
  parameter H_BP                  = 16'd132; 
  parameter V_ACTIVE              = 16'd400;
  parameter V_FP                  = 16'd89;
  parameter V_SYNC                = 16'd322;
  parameter V_BP                  = 16'd89;
  
  parameter H_TOTAL               = H_ACTIVE + H_FP + H_SYNC + H_BP;//Total line length
  parameter V_TOTAL               = V_ACTIVE + V_FP + V_SYNC + V_BP;//Total field length
  /*********Color bar RGB color bar Color parameter definition*****************************/
  parameter WHITE_R               = 8'hff;
  parameter WHITE_G               = 8'hff;
  parameter WHITE_B               = 8'hff;
  parameter YELLOW_R              = 8'hff;
  parameter YELLOW_G              = 8'hff;
  parameter YELLOW_B              = 8'h00;                                
  parameter CYAN_R                = 8'h00;
  parameter CYAN_G                = 8'hff;
  parameter CYAN_B                = 8'hff;                               
  parameter GREEN_R               = 8'h00;
  parameter GREEN_G               = 8'hff;
  parameter GREEN_B               = 8'h00;
  parameter MAGENTA_R             = 8'hff;
  parameter MAGENTA_G             = 8'h00;
  parameter MAGENTA_B             = 8'hff;
  parameter RED_R                 = 8'hff;
  parameter RED_G                 = 8'h00;
  parameter RED_B                 = 8'h00;
  parameter BLUE_R                = 8'h00;
  parameter BLUE_G                = 8'h00;
  parameter BLUE_B                = 8'hff;
  parameter BLACK_R               = 8'h00;
  parameter BLACK_G               = 8'h00;
  parameter BLACK_B               = 8'h00;

  reg                               hs_reg;//Define a register for line synchronization
  reg                               vs_reg;//Define a register, user field synchronization
  reg                               hs_reg_d0;//hs_reg one clock delay
                                              //All suffixes with _d0, d1, d2, etc. are the delay of a certain register
  reg                               vs_reg_d0;//vs_reg one clock delay
  reg  [11:0]                       h_cnt;//Counter for rows
  reg  [11:0]                       v_cnt;//Counter for field (frame)
  reg  [11:0]                       active_x;//The coordinate x of the effective image
  reg  [11:0]                       active_y;//The effective image coordinate y
  reg  [7:0]                        rgb_r_reg;//Pixel data r component
  reg  [7:0]                        rgb_g_reg;//Pixel data g component
  reg  [7:0]                        rgb_b_reg;//Pixel data b component
  reg  [1:0]                        data_cntr;
  reg  [1:0]                        data_cntr_d1;
  reg                               h_active;//Line image is valid
  reg                               v_active;//Field image is valid
  wire                              video_active;//The effective area of ​​the image in a frame h_active & v_active
  reg                               video_active_d0;
  reg                               en_cam_d1;
  reg                               en_cam_sync;
  
  wire [15:0]                       Y_i;      //Pixel data, red component
  wire [15:0]                       Cb_i;     //Pixel data, green component
  wire [15:0]                       Cr_i;     //Pixel data, blue component
  
  wire [10:0]                       rom_addr;
  wire [7:0]                        rom_dout;
  reg  [7:0]                        line_cntr;
  reg  [7:0]                        rom_dout_d1;
  wire                              eol;
  
  assign hs = hs_reg_d0;
  assign vs = vs_reg_d0;

  assign video_active = h_active & v_active;
  assign de = video_active_d0;


  // Synchronize Camera control bit
  always@(posedge clk) begin
    en_cam_d1   <= en_cam;
    en_cam_sync <= en_cam_d1;
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      hs_reg_d0 <= 1'b0;
      vs_reg_d0 <= 1'b0;
      video_active_d0 <= 1'b0;
    end else begin
      hs_reg_d0 <= hs_reg;
      vs_reg_d0 <= vs_reg;
      video_active_d0 <= video_active;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      data_cntr <= 2'b0;
    end else if(video_active) begin
      data_cntr <= data_cntr + 1;
    end else begin
      data_cntr <= 2'b0;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      data_cntr_d1 <= 2'b0;
    end else begin
      data_cntr_d1 <= data_cntr;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      h_cnt <= 12'd0;
    end else if (en_cam_sync) begin
      if(h_cnt == H_TOTAL - 1) begin //Clear line counter to maximum value
        h_cnt <= 12'd0;
      end else begin
        h_cnt <= h_cnt + 12'd1;
      end
    end else begin
      h_cnt <= 12'd0;
    end
  end
  
  `ifdef BAR_PATTERN
    reg[11:0] bar_cnt; //The coordinate x of the effective image
    always@(posedge clk or posedge rst) begin
      if(rst) begin
        bar_cnt <= 12'd0;
      end else if (video_active) begin
        bar_cnt <= bar_cnt + 12'd1;//Bar pattern
      end else begin
        bar_cnt <= 12'd0;
      end
    end
  `else
    wire [11:0] bar_cnt;//The coordinate x of the effective image
    `ifdef WHITE_OLED
      assign bar_cnt = 12'd0;            //Full white screen
    `elsif BLACK_OLED
      assign bar_cnt = (H_ACTIVE/8) * 7; //Full black screen
    `elsif BLUE_OLED
      assign bar_cnt = (H_ACTIVE/8) * 6; //Full blue screen
    `else
      assign bar_cnt = 12'd0;
    `endif
  `endif
  
  //  always@(rst) begin
  //    `ifdef WHITE_OLED
  //      bar_cnt <= 12'd0;            //Full white screen
  //    `elsif BLACK_OLED
  //      bar_cnt <= (H_ACTIVE/8) * 7; //Full black screen
  //    `elsif BLUE_OLED
  //      bar_cnt <= (H_ACTIVE/8) * 6; //Full blue screen
  //    `else
  //      bar_cnt <= 12'd0;
  //    `endif
  //  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      active_x <= 12'd0;
    end else if(h_cnt >= H_FP + H_SYNC + H_BP - 1) begin//Calculate the x coordinate of the image
      active_x <= h_cnt - (H_FP[11:0] + H_SYNC[11:0] + H_BP[11:0] - 12'd1);
    end else begin
      active_x <= active_x;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      v_cnt <= 12'd0;
    end else if(h_cnt == H_FP  - 1) begin//When the line counter is H_FP-1, the field counter is +1 or cleared
      if(v_cnt == V_TOTAL - 1) begin//The field counter reaches the maximum value, clear it
        v_cnt <= 12'd0;
      end else begin
        v_cnt <= v_cnt + 12'd1;//Less than the maximum value, +1
      end
    end else begin
      v_cnt <= v_cnt;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      hs_reg <= 1'b0;
    end else if(h_cnt == H_FP - 1) begin//Line synchronization has started...
      hs_reg <= 1'b1;
    end else if(h_cnt == H_FP + H_SYNC - 1) begin//Line synchronization is over at this time
      hs_reg <= 1'b0;
    end else begin
      hs_reg <= hs_reg;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      h_active <= 1'b0;
    end else if(h_cnt == H_FP + H_SYNC + H_BP - 1) begin
      h_active <= 1'b1;
    end else if(h_cnt == H_TOTAL - 1) begin
      h_active <= 1'b0;
    end else begin
      h_active <= h_active;
    end 
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      vs_reg <= 1'd0;
    end else if((v_cnt == V_FP - 1) && (h_cnt == H_FP - 1)) begin
      vs_reg <= 1'b1;
    end else if((v_cnt == V_FP + V_SYNC - 1) && (h_cnt == H_FP - 1)) begin
      vs_reg <= 1'b0;  
    end else begin
      vs_reg <= vs_reg;
    end
  end
  
  always@(posedge clk or posedge rst)
  begin
    if(rst) begin
      v_active <= 1'd0;
    end else if((v_cnt == V_FP + V_SYNC + V_BP - 1) && (h_cnt == H_FP - 1)) begin
      v_active <= 1'b1;
    end else if((v_cnt == V_TOTAL - 1) && (h_cnt == H_FP - 1)) begin
      v_active <= 1'b0;  
    end else begin
      v_active <= v_active;
    end 
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      rgb_r_reg <= 8'h00;
      rgb_g_reg <= 8'h00;
      rgb_b_reg <= 8'h00;
    end else begin //if(video_active)
      //Yellow line at center
      `ifdef YELLOW_CROSS
      if(v_cnt == `CROSS_LINE_NUM || (h_cnt >= `CROSS_PIX_START && h_cnt <= `CROSS_PIX_END)) begin
        rgb_r_reg <= YELLOW_R;
        rgb_g_reg <= YELLOW_G;
        rgb_b_reg <= YELLOW_B;
      end else `elsif WHITE_CROSS if(v_cnt == `CROSS_LINE_NUM || (h_cnt >= `CROSS_PIX_START && h_cnt <= `CROSS_PIX_END)) begin
        rgb_r_reg <= WHITE_R;
        rgb_g_reg <= WHITE_G;
        rgb_b_reg <= WHITE_B;
      end else `elsif RED_CROSS if(v_cnt == `CROSS_LINE_NUM || (h_cnt >= `CROSS_PIX_START && h_cnt <= `CROSS_PIX_END)) begin
        rgb_r_reg <= RED_R;
        rgb_g_reg <= RED_G;
        rgb_b_reg <= RED_B;
      end else `elsif BLUE_CROSS if(v_cnt == `CROSS_LINE_NUM || (h_cnt >= `CROSS_PIX_START && h_cnt <= `CROSS_PIX_END)) begin
        rgb_r_reg <= BLUE_R;
        rgb_g_reg <= BLUE_G;
        rgb_b_reg <= BLUE_B;
      end else `elsif GREEN_CROSS if(v_cnt == `CROSS_LINE_NUM || (h_cnt >= `CROSS_PIX_START && h_cnt <= `CROSS_PIX_END)) begin
        rgb_r_reg <= GREEN_R;
        rgb_g_reg <= GREEN_G;
        rgb_b_reg <= GREEN_B;
      end else `endif if(bar_cnt == 12'd0) begin
        rgb_r_reg <= WHITE_R;
        rgb_g_reg <= WHITE_G;
        rgb_b_reg <= WHITE_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 1) begin
        rgb_r_reg <= YELLOW_R;
        rgb_g_reg <= YELLOW_G;
        rgb_b_reg <= YELLOW_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 2) begin
        rgb_r_reg <= CYAN_R;
        rgb_g_reg <= CYAN_G;
        rgb_b_reg <= CYAN_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 3) begin
        rgb_r_reg <= GREEN_R;
        rgb_g_reg <= GREEN_G;
        rgb_b_reg <= GREEN_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 4) begin
        rgb_r_reg <= MAGENTA_R;
        rgb_g_reg <= MAGENTA_G;
        rgb_b_reg <= MAGENTA_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 5) begin
        rgb_r_reg <= RED_R;
        rgb_g_reg <= RED_G;
        rgb_b_reg <= RED_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 6) begin
        rgb_r_reg <= BLUE_R;
        rgb_g_reg <= BLUE_G;
        rgb_b_reg <= BLUE_B;
      end else if(bar_cnt == (H_ACTIVE/8) * 7) begin
        rgb_r_reg <= BLACK_R;
        rgb_g_reg <= BLACK_G;
        rgb_b_reg <= BLACK_B;
      end 
    end
  end

  assign Y_i  = 16'd16  + (((rgb_r_reg<<6)+(rgb_r_reg<<1)+(rgb_g_reg<<7)+rgb_g_reg+(rgb_b_reg<<4)+(rgb_b_reg<<3)+rgb_b_reg)>>8);
  assign Cb_i = 16'd128 + ((-((rgb_r_reg<<5)+(rgb_r_reg<<2)+(rgb_r_reg<<1))-((rgb_g_reg<<6)+(rgb_g_reg<<3)+(rgb_g_reg<<1))+(rgb_b_reg<<7)-(rgb_b_reg<<4))>>8);
  assign Cr_i = 16'd128 + (((rgb_r_reg<<7)-(rgb_r_reg<<4)-((rgb_g_reg<<6)+(rgb_g_reg<<5)-(rgb_g_reg<<1))-((rgb_b_reg<<4)+(rgb_b_reg<<1)))>>8);
   
  `ifdef GAO_BAR_PATTERN
    //NOTE:- Checksum for Test Frame = 0x37DF
    
    assign rom_addr = active_x < 1280 ? active_x[10:0] : 11'b0;
    rom_8x1280 i_rom_8x1280 (
        .dout    (rom_dout ), //output [7:0] dout
        .clk     (clk      ), //input clk
        .oce     (1'b1     ), //input oce
        .ce      (1'b1     ), //input ce
        .reset   (rst      ), //input reset
        .ad      (rom_addr )  //input [10:0] ad
    );
    always@(posedge clk or posedge rst) begin
      if(rst) begin
        rom_dout_d1 <= 8'd0;
      end else begin
        rom_dout_d1 <= rom_dout;
      end
    end
    
    assign eol = !video_active && video_active_d0;
    
    always@(posedge clk or posedge rst) begin
      if(rst) begin
        line_cntr <= 8'd1;
      end else if(v_active) begin
        if(line_cntr == 201) begin
          line_cntr <= 8'd1;
        end else if(eol) begin
          line_cntr <= line_cntr + 8'd1;
        end
      end else begin
        line_cntr <= 8'd1;
      end
    end
    
    assign data = rom_addr == 11'd1 ? line_cntr : rom_dout_d1;
  `else
    assign data = data_cntr_d1 == 2'b01 ? Cb_i :
                  data_cntr_d1 == 2'b11 ? Cr_i :
                                          Y_i;  
  `endif
  
endmodule 
`default_nettype wire