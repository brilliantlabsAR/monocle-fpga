`default_nettype none

module disp_sync_gen (
  clk,
  rst,
  enable,
  disp_grey,
  disp_bars,
  data,
  hs_n,
  vs_n,
  de
);
  // Video Timing Parameters
  parameter H_ACTIVE              = 16'd640;
  parameter H_FP                  = 16'd102;
  parameter H_SYNC                = 16'd64;
  parameter H_BP                  = 16'd58; 
  parameter V_ACTIVE              = 16'd400;
  parameter V_FP                  = 16'd187;
  parameter V_SYNC                = 16'd6;
  parameter V_BP                  = 16'd32;
                                  
  parameter H_TOTAL               = H_ACTIVE + H_FP + H_SYNC + H_BP; //Total line length
  parameter V_TOTAL               = V_ACTIVE + V_FP + V_SYNC + V_BP; //Total frame length
  
  // Bar Pattern
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
  
  // Busy screen                  
  parameter GREY_R                = 8'h80;
  parameter GREY_G                = 8'h80;
  parameter GREY_B                = 8'h80;

  input  wire                       clk;  //Pixel clock
  input  wire                       rst;
  input  wire                       enable;
  input  wire                       disp_grey;
  input  wire                       disp_bars;
  output wire [15:0]                data;
  output wire                       hs_n;
  output wire                       vs_n;
  output wire                       de;   //Data is valid
  

  reg                               hs_reg;
  reg                               vs_reg;
  reg                               hs_reg_d1;
  reg                               vs_reg_d1;
  reg  [11:0]                       h_cnt;
  reg  [11:0]                       v_cnt;
  reg                               h_active;
  reg                               v_active;
  wire                              video_active;    // Effective area of ​​the image in a frame
  reg                               video_active_d1;
  reg  [15:0]                       Y_i; 
  reg  [15:0]                       Cb_i;
  reg  [15:0]                       Cr_i;
  reg  [11:0]                       bar_cnt;
  reg                               data_cntr;
  reg                               data_cntr_d1;
  reg  [7:0]                        rgb_r_reg;
  reg  [7:0]                        rgb_g_reg;
  reg  [7:0]                        rgb_b_reg;
  

  //================================================
  // Horizontal Sync
  //================================================
  // Column Counter
  always @(posedge clk) begin
    if (rst) begin
      h_cnt <= 12'd0;
    end else if (enable) begin
      if (h_cnt == H_TOTAL - 1)
        h_cnt <= 12'd0;
      else
        h_cnt <= h_cnt + 12'd1;
    end else begin
      h_cnt <= 12'd0;
    end
  end
  
  always @(posedge clk) begin
    if (rst)
      hs_reg <= 1'b0;
    else if (h_cnt == H_FP - 1)         //Line synchronization has started...
      hs_reg <= 1'b1;
    else if (h_cnt == H_FP + H_SYNC - 1)//Line synchronization is over at this time
      hs_reg <= 1'b0;
    else
      hs_reg <= hs_reg;
  end  
  
  always @(posedge clk) begin
    if (rst) begin
      hs_reg_d1 <= 1'b0;
    end else begin
      hs_reg_d1 <= hs_reg;
    end
  end
  
  assign hs_n = ~hs_reg_d1;  
  
  always @(posedge clk) begin
    if (rst)
      h_active <= 1'b0;
    else if (h_cnt == H_FP + H_SYNC + H_BP - 1)
      h_active <= 1'b1;
    else if (h_cnt == H_TOTAL - 1)
      h_active <= 1'b0;
    else
      h_active <= h_active;
  end
  
  //================================================
  // Vertical Sync
  //================================================
  // Row Counter
  always @(posedge clk) begin
    if (rst)
      v_cnt <= 12'd0;
    else if (h_cnt == H_FP  - 1)//When the line counter is H_FP-1, the frame counter is +1 or cleared
      if (v_cnt == V_TOTAL - 1) //The frame counter reaches the maximum value, clear it
        v_cnt <= 12'd0;
      else
        v_cnt <= v_cnt + 12'd1;//Less than the maximum value, +1
    else
      v_cnt <= v_cnt;
  end

  always @(posedge clk) begin
    if (rst)
      vs_reg <= 1'd0;
    else if ((v_cnt == V_FP - 1) && (h_cnt == H_FP - 1))
      vs_reg <= 1'b1;
    else if ((v_cnt == V_FP + V_SYNC - 1) && (h_cnt == H_FP - 1))
      vs_reg <= 1'b0;  
    else
      vs_reg <= vs_reg;
  end
  
  always @(posedge clk) begin
    if (rst) begin
      vs_reg_d1 <= 1'b0;
    end else begin
      vs_reg_d1 <= vs_reg;
    end
  end

  assign vs_n = ~vs_reg_d1;
  
  always @(posedge clk) begin
    if (rst)
      v_active <= 1'd0;
    else if ((v_cnt == V_FP + V_SYNC + V_BP - 1) && (h_cnt == H_FP - 1))
      v_active <= 1'b1;
    else if ((v_cnt == V_TOTAL - 1) && (h_cnt == H_FP - 1))
      v_active <= 1'b0;  
    else
      v_active <= v_active;
  end
  
  //================================================
  // Data Valid
  //================================================
  assign video_active = h_active & v_active;
  
  always @(posedge clk) begin
    if (rst) begin
      video_active_d1 <= 1'b0;
    end else begin
      video_active_d1 <= video_active;
    end
  end
  
  assign de = video_active_d1;
  
  //================================================
  // Data
  //================================================  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      data_cntr <= 1'b0;
    end else if(video_active) begin
      data_cntr <= ~data_cntr;
    end else begin
      data_cntr <= 1'b0;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      data_cntr_d1 <= 1'b0;
    end else begin
      data_cntr_d1 <= data_cntr;
    end
  end

  always@(posedge clk or posedge rst) begin
    if(rst) begin
      bar_cnt <= 12'd0;
    end else begin
      if(disp_bars & video_active) begin
        bar_cnt <= bar_cnt + 12'd1;//Bar pattern
      end else begin
        bar_cnt <= 12'd0;
      end
    end
  end

  always @(posedge clk) begin
    if(disp_grey)
      begin
        rgb_r_reg <= GREY_R;
        rgb_g_reg <= GREY_G;
        rgb_b_reg <= GREY_B;
      end
    else if(bar_cnt == 12'd0)
      begin
        rgb_r_reg <= WHITE_R;
        rgb_g_reg <= WHITE_G;
        rgb_b_reg <= WHITE_B;
      end
    else if(bar_cnt == (H_ACTIVE/8) * 1)
      begin
        rgb_r_reg <= YELLOW_R;
        rgb_g_reg <= YELLOW_G;
        rgb_b_reg <= YELLOW_B;
      end      
    else if(bar_cnt == (H_ACTIVE/8) * 2)
      begin
        rgb_r_reg <= CYAN_R;
        rgb_g_reg <= CYAN_G;
        rgb_b_reg <= CYAN_B;
      end
    else if(bar_cnt == (H_ACTIVE/8) * 3)
      begin
        rgb_r_reg <= GREEN_R;
        rgb_g_reg <= GREEN_G;
        rgb_b_reg <= GREEN_B;
      end
    else if(bar_cnt == (H_ACTIVE/8) * 4)
      begin
        rgb_r_reg <= MAGENTA_R;
        rgb_g_reg <= MAGENTA_G;
        rgb_b_reg <= MAGENTA_B;
      end
    else if(bar_cnt == (H_ACTIVE/8) * 5)
      begin
        rgb_r_reg <= RED_R;
        rgb_g_reg <= RED_G;
        rgb_b_reg <= RED_B;
      end
    else if(bar_cnt == (H_ACTIVE/8) * 6)
      begin
        rgb_r_reg <= BLUE_R;
        rgb_g_reg <= BLUE_G;
        rgb_b_reg <= BLUE_B;
      end  
    else if(bar_cnt == (H_ACTIVE/8) * 7)
      begin
        rgb_r_reg <= BLACK_R;
        rgb_g_reg <= BLACK_G;
        rgb_b_reg <= BLACK_B;
      end
    //else if(bar_cnt == (H_ACTIVE/8) * 8)
    //  begin
    //    rgb_r_reg <= GREY_R;
    //    rgb_g_reg <= GREY_G;
    //    rgb_b_reg <= GREY_B;
    //  end
    else
      begin
        rgb_r_reg <= rgb_r_reg;
        rgb_g_reg <= rgb_g_reg;
        rgb_b_reg <= rgb_b_reg;
      end      
  end
  
  always @(*) begin
    if(rst) begin
      Y_i  <= 16'd0;
      Cb_i <= 16'd0;
      Cr_i <= 16'd0;
    end else begin
      Y_i  <= 16'd16  + (((rgb_r_reg<<6)+(rgb_r_reg<<1)+(rgb_g_reg<<7)+rgb_g_reg+(rgb_b_reg<<4)+(rgb_b_reg<<3)+rgb_b_reg)>>8);
      Cb_i <= 16'd128 + ((-((rgb_r_reg<<5)+(rgb_r_reg<<2)+(rgb_r_reg<<1))-((rgb_g_reg<<6)+(rgb_g_reg<<3)+(rgb_g_reg<<1))+(rgb_b_reg<<7)-(rgb_b_reg<<4))>>8);
      Cr_i <= 16'd128 + (((rgb_r_reg<<7)-(rgb_r_reg<<4)-((rgb_g_reg<<6)+(rgb_g_reg<<5)-(rgb_g_reg<<1))-((rgb_b_reg<<4)+(rgb_b_reg<<1)))>>8);
    end
  end
  
  assign data = data_cntr_d1 == 1'b1 ? {Cr_i[7:0], Y_i[7:0]} : 
                                       {Cb_i[7:0], Y_i[7:0]};
  
endmodule

`default_nettype wire