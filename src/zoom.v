`default_nettype none

`include "defines.v"

module zoom (
  rst,
  clk,
  en,
  sel_zoom_mode,
  rd_ctrl_req,
  // Upstream Interface
  us_vld,
  zoom_rdy,
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
  input  wire [1:0]                 sel_zoom_mode;
  output wire                       rd_ctrl_req;
  // Upstream Interface
  input  wire                       us_vld;
  output wire                       zoom_rdy;
  input  wire [`DSIZE-1:0]          us_rd_data;
  // Downstream Interface
  output wire                       ds_vld;
  input  wire                       ds_rdy;
  output wire [`DSIZE-1:0]          ds_rd_data;

  // Local Parameters
  localparam  ZOOM_CNT_WIDTH      = 3; // Max upto 8x
  
  // Internal Signals
  reg  [ZOOM_CNT_WIDTH-1:0]         col_dup_cntr;
  reg  [ZOOM_CNT_WIDTH-1:0]         row_dup_cntr;
  reg  [9:0]                        addr_cntr;
  wire [9:0]                        sdp_raddr;
  reg  [9:0]                        sdp_raddr_i;
  wire                              wr_en;
  wire                              rd_en;
  wire [`DSIZE-1:0]                 us_line_data;
  wire [`DSIZE-1:0]                 dup_line_rd_data;
  wire [ZOOM_CNT_WIDTH-1:0]         zoom_x;
  wire                              eol;
  wire                              col_dup_done;
  wire                              row_dup_done;
  wire                              zoom_data_vld;
  wire                              col_dup;
  wire                              line_dup;
  wire                              zoom_sof;
  wire                              zoom_eof;
  wire [`DSIZE-1:0]                 zoom_rd_data;
  wire                              eof;
  reg  [31:0]                       in_byte_cntr;
  reg  [31:0]                       out_byte_cntr;
  
//  // For Debug only
//  always @(posedge clk or posedge rst) begin
//    if (rst || (us_vld && zoom_rdy && us_rd_data[33])) begin
//      in_byte_cntr <= 32'd0;
//    end else if(us_vld && zoom_rdy) begin
//      in_byte_cntr <= in_byte_cntr + 4;
//    end
//  end
//  always @(posedge clk or posedge rst) begin
//    if (rst || (ds_vld && ds_rdy && ds_rd_data[33])) begin
//      out_byte_cntr <= 32'd0;
//    end else if(ds_vld && ds_rdy) begin
//      out_byte_cntr <= out_byte_cntr + 4;
//    end
//  end
  
  //================================================
  // Write
  //================================================ 
  assign wr_en = en & (!line_dup) & us_vld & ds_rdy ? 1'b1 : 1'b0;

  // Line Buffer Simple Dual Port BRAM
  always @(posedge clk) begin
    if (rst) begin
      addr_cntr <= 10'b0;
    end else if (wr_en | rd_en) begin
      if (eol) begin
        addr_cntr <= 10'b0;
      end else begin
        addr_cntr <= addr_cntr + 10'h1;
      end
    end
  end
  
  assign eol = (addr_cntr == (`MAX_FRM_COL>>2)-1) ? 1'b1 : 1'b0;
  
  //================================================
  // SDP BRAM for Line duplication
  //================================================ 
  assign zoom_eof = eol & us_rd_data[33];
  assign us_line_data = {2'b00, zoom_eof, 1'b0, us_rd_data[31:0]};
  
  simple_dpram_sclk  #(
    .ADDR_WIDTH     (10),
    .DATA_WIDTH     (`DSIZE),
    .ENABLE_BYPASS  (0 )
  ) i_line_bram (
    .clk            (clk),
    .waddr          (addr_cntr),
    .we             (wr_en),
    .din            (us_line_data),
    .raddr          (sdp_raddr),
    .re             (1'b1),
    .dout           (dup_line_rd_data)
    );
  
  //================================================
  // Read
  //================================================   
  assign rd_en =  en & line_dup & ds_rdy ? 1'b1 : 1'b0;

  always @(posedge clk) begin
    if (rst) begin
      sdp_raddr_i <= 10'b0;
    end else begin
      sdp_raddr_i <= sdp_raddr;
    end
  end
  
  assign sdp_raddr = rd_en && eol ? 10'b0 : (sdp_raddr_i + rd_en);
  
  
  
  
  
  //================================================
  // Duplication
  //================================================  
  // Column duplication
  always @(posedge clk) begin
    if (rst) begin
      col_dup_cntr <= {ZOOM_CNT_WIDTH{1'b0}};
    end else if (wr_en) begin
      if (col_dup_done) begin
        col_dup_cntr <= {ZOOM_CNT_WIDTH{1'b0}};
      end else begin
        col_dup_cntr <= col_dup_cntr + 'h1;
      end
    end
  end
  
  assign zoom_x = sel_zoom_mode == 2'b10 ? 3'b111 : //8x
                  sel_zoom_mode == 2'b01 ? 3'b011 : //4x
                                           3'b001 ; //2x
  
  assign col_dup_done = col_dup_cntr == zoom_x ? 1'b1 : 1'b0;
  assign zoom_data_vld = us_vld & col_dup_done;
  
  // Row duplication
  always @(posedge clk) begin
    if (rst) begin
      row_dup_cntr <= {ZOOM_CNT_WIDTH{1'b0}};
    end else if (ds_rdy & ds_vld & eol) begin
      if (row_dup_done) begin
        row_dup_cntr <= {ZOOM_CNT_WIDTH{1'b0}};
      end else begin
        row_dup_cntr <= row_dup_cntr + 'h1;
      end
    end
  end
  
  assign row_dup_done = row_dup_cntr == zoom_x ? 1'b1 : 1'b0;
  
  assign col_dup = col_dup_cntr != {ZOOM_CNT_WIDTH{1'b0}} ? 1'b1 : 1'b0;
  assign line_dup = row_dup_cntr != {ZOOM_CNT_WIDTH{1'b0}} ? 1'b1 : 1'b0;
  
  assign zoom_sof = col_dup_cntr == {ZOOM_CNT_WIDTH{1'b0}} ? us_rd_data[32] : 1'b0;
  assign zoom_rd_data = line_dup ? dup_line_rd_data : {3'b000, zoom_sof, us_rd_data[31:0]};
  
  assign eof = ((en && row_dup_done && zoom_rd_data[33]) || (!en && us_rd_data[33]));
  
  assign rd_ctrl_req = eof && ds_vld && ds_rdy;
  
  //================================================
  // Bypass Zoom if disable
  //================================================
  assign zoom_rdy   = en ? ((!line_dup) & col_dup_done & ds_rdy ? 1'b1 : 1'b0): ds_rdy;
  assign ds_vld     = us_vld || line_dup;
  assign ds_rd_data = en ? {zoom_rd_data[35:34], eof, zoom_rd_data[32:0]} : us_rd_data;
    
endmodule
`default_nettype wire