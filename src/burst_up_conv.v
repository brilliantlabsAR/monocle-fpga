`default_nettype none

`include "defines.v"

module burst_up_conv (
  rst,
  clk,
  // Upstream Interface
  s_vld_i,
  s_rdy_o,
  s_data_i,
  // Downstream Interface
  ds_burst_avail,
  ds_rd_en,
  ds_rd_data,
  ds_full_err
);
  
  input  wire                       rst;
  input  wire                       clk;
  // Upstream Interface
  input  wire                       s_vld_i;
  output wire                       s_rdy_o;
  input  wire [`SYS_DSIZE-1:0]      s_data_i;
  // Downstream Interface
  output wire                       ds_burst_avail;
  input  wire                       ds_rd_en;
  output wire [`MEM_DSIZE-1:0]      ds_rd_data;
  output reg                        ds_full_err;

  // Local Parameters
  
  // Internal Signals
  wire                              fifo_wr_en;
  wire                              fifo_empty;
  wire                              fifo_full;
  wire                              fifo_rdy;
  wire [10:0]                       fifo_data_count;
  wire [31:0]                       fifo_wdata;
  wire [`MEM_DSIZE-1:0]             fifo_wdata_i;
  wire [1:0]                        be;
  wire                              eof;

  // Data Conversion 8bit to 32bit
  dc_8to32 i_dc_8to32 (
    .clk                (clk),
    .rst                (rst),
    .s_vld_i            (s_vld_i),
    .s_rdy_o            (s_rdy_o),
    .s_data_i           (s_data_i[7:0]),
    .s_eof_i            (s_data_i[8]),
    .m_vld_o            (fifo_wr_en),
    .m_rdy_i            (fifo_rdy),
    .m_data_o           (fifo_wdata),
    .m_be_o             (be),
    .m_eof_o            (eof)
  );
  
  assign fifo_rdy     = ~fifo_full;
  assign fifo_wdata_i = {be, eof, 1'b0, fifo_wdata};
  
  fifo_fwft_36x1024 i_fifo_fwft_36x1024 (
    .Clk                (clk),
    .Reset              (rst),
    .WrEn               (fifo_wr_en),
    .Data               (fifo_wdata_i),
    .Almost_Full        (),
    .Full               (fifo_full),
    .Wnum               (fifo_data_count),//11bit
    .RdEn               (ds_rd_en),
    .Q                  (ds_rd_data),
    .Almost_Empty       (),
    .Empty              (fifo_empty) 
  );
  
  assign ds_burst_avail = (!fifo_empty) & fifo_data_count >= `MEM_WR_BL ? 1'b1 : 1'b0;
  
  // Error
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      ds_full_err <= 1'b0;
    end else if(fifo_full & fifo_wr_en) begin
      ds_full_err <= 1'b1;
      $display ("ERROR: Burst Up Convertor FIFO full error..!");
      $stop;
    end      
  end
  
endmodule
`default_nettype wire