`default_nettype none

`include "defines.v"
module rb_shift (
  rst,
  clk,
  en,
  vld_i,
  rb_rdy,
  din,
  vld_o,
  ds_rdy,
  dout
);
  
  // Function Declaration
  `include "functions.v" 
  
  // Upstream Interface
  input  wire                       rst;
  input  wire                       clk;
  input  wire                       en;
  input  wire                       vld_i;
  output wire                       rb_rdy;
  input  wire [`DSIZE-1:0]          din;
  output reg                        vld_o;
  input  wire                       ds_rdy;
  output wire [`DSIZE-1:0]          dout;
  
  wire                              rb_shift_vld;
  wire [7:0]                        y0;
  wire [7:0]                        cb;
  wire [7:0]                        y1;
  wire [7:0]                        cr;
  wire [23:0]                       rgb0;
  wire [23:0]                       rgb1;
  wire [7:0]                        r0_i;
  wire [7:0]                        g0_i;
  wire [7:0]                        b0_i;
  wire [7:0]                        r1_i;
  wire [7:0]                        g1_i;
  wire [7:0]                        b1_i;
  reg  [9:0]                        line_byte_cntr;
  reg  [8:0]                        line_cntr;
  wire                              eol;
  wire                              eof;
  wire                              r_wr_vld;
  wire                              g_wr_vld;
  wire                              b_wr_vld;
  wire                              gfifo_wr_en;
  wire                              gfifo_rd_en;
  wire [17:0]                       gfifo_wdata;
  wire [17:0]                       gfifo_rd_data;
  wire                              gfifo_full;
  wire                              gfifo_empty;
  reg                               gfifo_overrun;
  reg                               gfifo_underrun;
  wire                              bfifo_wr_en;
  wire                              bfifo_rd_en;
  wire [17:0]                       bfifo_wdata;
  wire [17:0]                       bfifo_rd_data;
  wire                              bfifo_full;
  wire                              bfifo_empty;
  reg                               bfifo_overrun;
  reg                               bfifo_underrun;
  reg                               en_d1;
  reg                               en_sync;
  reg                               lch_en;
  wire [7:0]                        r0_o;
  wire [7:0]                        g0_o;
  wire [7:0]                        b0_o;
  wire [7:0]                        r1_o;
  wire [7:0]                        g1_o;
  wire [7:0]                        b1_o;
  wire [23:0]                       ycbcr0;
  wire [23:0]                       ycbcr1;
  wire [7:0]                        y0_o;
  wire [7:0]                        cb_o;
  wire [7:0]                        y1_o;
  wire [7:0]                        cr_o;
  wire [31:0]                       ycbcr_o;
  wire [3:0]                        sb;
  
  reg  [7:0]                        r0_o_d1;
  reg  [7:0]                        g0_o_d1;
  reg  [7:0]                        b0_o_d1;
  reg  [7:0]                        r1_o_d1;
  reg  [7:0]                        g1_o_d1;
  reg  [7:0]                        b1_o_d1;
  reg  [3:0]                        sb_d1;
  reg  [`DSIZE-1:0]                 din_d1;
  
  // Synchronize Control bit
  always@(posedge clk) begin
    en_d1   <= en;
    en_sync <= en_d1;
  end
  
  `ifdef SIM_ENABLE
    always @(*) begin
      lch_en <= en_sync;
    end
  `else
    always @(posedge clk or posedge rst) begin
      if (rst) begin
        lch_en <= 1'b0;
      end else if (eof) begin
        lch_en <= en_sync;
      end
    end
  `endif
  
  assign rb_shift_vld = lch_en && vld_i && rb_rdy;
  
  //================================================
  // YCbCr2RGB
  //================================================
  // Seperate Y, Cb and Cr
  assign y0 = din[0+:8];
  assign cb = din[8+:8];
  assign y1 = din[16+:8];
  assign cr = din[24+:8];
  
  assign rgb0 = ycbcr422torgb888(y0, cb, cr);
  assign rgb1 = ycbcr422torgb888(y1, cb, cr);
  
  assign r0_i = rgb0[16+:8];
  assign g0_i = rgb0[8+:8];
  assign b0_i = rgb0[0+:8];
  
  assign r1_i = rgb1[16+:8];
  assign g1_i = rgb1[8+:8];
  assign b1_i = rgb1[0+:8];
  
  //================================================
  // RB Shift Logic
  //================================================
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      line_byte_cntr <= 10'd0;
    end else if(eol) begin
      line_byte_cntr <= 10'd0;
    end else if(rb_shift_vld) begin
      line_byte_cntr <= line_byte_cntr + 10'd1;
    end
  end
  
  assign eol = ds_rdy && (line_byte_cntr == (`MAX_FRM_COL>>2)-1) ? 1'b1 : 1'b0;
  
  assign eof = vld_i && ds_rdy && din[33];
  
  // Count from 0 to 402
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      line_cntr <= 9'd0;
    end else if (eof) begin
      line_cntr <= 9'd0;
    end else if (eol) begin
      line_cntr <= line_cntr + 9'b1;
    end
  end
  
  assign r_wr_vld = line_cntr > `R_START_LINE-1 && line_cntr < `R_END_LINE ? rb_shift_vld : 1'b0;
  assign g_wr_vld = line_cntr > `G_START_LINE-1 && line_cntr < `G_END_LINE ? rb_shift_vld : 1'b0; // Drop top 3 lines
  assign b_wr_vld =                                line_cntr < `B_END_LINE ? rb_shift_vld : 1'b0;
  
  assign gfifo_wr_en = !gfifo_full && g_wr_vld;
  assign bfifo_wr_en = !bfifo_full && b_wr_vld;
  
  assign gfifo_wdata = {2'b0, g1_i, g0_i};
  assign bfifo_wdata = {2'b0, b1_i, b0_i};
  
  // G Line Buffer
  fifo_fwft_18x1024 i_gfifo_18x1024 (
    .Clk                 (clk            ),
    .Reset               (rst            ),
    .WrEn                (gfifo_wr_en    ),
    .Data                (gfifo_wdata    ),
    .Almost_Full         (               ),
    .Full                (gfifo_full     ),
    .Wnum                (               ),
    .RdEn                (gfifo_rd_en    ),
    .Q                   (gfifo_rd_data  ),
    .Almost_Empty        (               ),
    .Empty               (gfifo_empty    ) 
  );
  
  // B Line Buffer
  fifo_fwft_18x2048 i_bfifo_18x2048 (
    .Clk                 (clk            ),
    .Reset               (rst            ),
    .WrEn                (bfifo_wr_en    ),
    .Data                (bfifo_wdata    ),
    .Almost_Full         (               ),
    .Full                (bfifo_full     ),
    .Wnum                (               ),
    .RdEn                (bfifo_rd_en    ),
    .Q                   (bfifo_rd_data  ),
    .Almost_Empty        (               ),
    .Empty               (bfifo_empty    ) 
  );

  // R without buffering
  assign r0_o = r0_i;
  assign r1_o = r1_i;
  
  // G 1 line buffering
  assign gfifo_rd_en = !gfifo_empty && r_wr_vld;
  assign g0_o = gfifo_rd_data[7:0];
  assign g1_o = gfifo_rd_data[15:8];
  
  // B 3 line buffering
  assign bfifo_rd_en = !bfifo_empty && r_wr_vld;
  assign b0_o = bfifo_rd_data[7:0];
  assign b1_o = bfifo_rd_data[15:8];
  
  // Pipeline to resolve the timing error
  always@(posedge clk) begin
    r0_o_d1 <= r0_o;
	g0_o_d1 <= g0_o;
	b0_o_d1 <= b0_o;
    r1_o_d1 <= r1_o;
	g1_o_d1 <= g1_o;
	b1_o_d1 <= b1_o;
	
	sb_d1 <= sb;
  end
  
  //================================================
  // RGB2YCbCr
  //================================================
  assign ycbcr0 = rgb888toycbcr422(r0_o_d1, g0_o_d1, b0_o_d1);
  assign ycbcr1 = rgb888toycbcr422(r1_o_d1, g1_o_d1, b1_o_d1);
  
  assign y0_o = ycbcr0[16+:8];
  assign cb_o = ycbcr0[8+:8];
  assign y1_o = ycbcr1[16+:8];
  assign cr_o = ycbcr0[0+:8];
  
  assign ycbcr_o  = line_cntr < 4 ? {8'h80, 8'h0, 8'h80, 8'h0} :  // Black lines
                                    {cr_o,  y1_o, cb_o,  y0_o};   // Useful lines
  assign sb = din[35:32];
  
  // Pipeline to resolve the timing error
  always@(posedge clk) begin
    vld_o <= vld_i;
    din_d1 <= din;
  end
  
  //assign vld_o = vld_i;
  assign rb_rdy = ds_rdy;
  assign dout  = lch_en ? {sb_d1, ycbcr_o} : din_d1;

  //================================================
  // Debug
  //================================================  
  // Raise Error flag when fifo gets full
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      gfifo_overrun <= 1'b0;
    end else if(gfifo_full && g_wr_vld) begin
      gfifo_overrun <= 1'b1;
      $display ("ERROR: RB Shift gfifo FULL error..!");
      $stop;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      bfifo_overrun <= 1'b0;
    end else if(bfifo_full && b_wr_vld) begin
      bfifo_overrun <= 1'b1;
      $display ("ERROR: RB Shift bfifo FULL error..!");
      $stop;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      gfifo_underrun <= 1'b0;
    end else if(gfifo_empty && r_wr_vld) begin
      gfifo_underrun <= 1'b1;
      $display ("ERROR: RB Shift gfifo EMPTY error..!");
      $stop;
    end
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      bfifo_underrun <= 1'b0;
    end else if(bfifo_empty && r_wr_vld) begin
      bfifo_underrun <= 1'b1;
      $display ("ERROR: RB Shift bfifo EMPTY error..!");
      $stop;
    end
  end

endmodule

`default_nettype wire