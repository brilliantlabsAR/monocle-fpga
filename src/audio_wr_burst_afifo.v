`default_nettype none

`include "defines.v"

module audio_wr_burst_afifo (
  // Upstream
  wr_rst,
  wr_clk,
  wr_vld_i,
  wr_rdy_o,
  wr_data_i,
  // Downstream
  rd_rst,
  rd_clk,
  burst_avail,
  burst_rd_en,
  burst_rd_data,
  err_bfifo_full
);
  
  // Upstream Interface
  input  wire                       wr_rst;
  input  wire                       wr_clk;
  input  wire                       wr_vld_i;
  output wire                       wr_rdy_o;
  input  wire [`PCM_DSIZE-1:0]      wr_data_i;
  // Downstream Interface
  input  wire                       rd_rst;
  input  wire                       rd_clk;
  output wire                       burst_avail;
  input  wire                       burst_rd_en;
  output wire [`DSIZE-1:0]          burst_rd_data;
  output reg                        err_bfifo_full;

  // Local Parameters
  
  // Internal Signals
  wire                              full;
  wire                              empty;
  wire [31:0]                       burst_rd_data_i;
  wire [9:0]                        rd_data_count;
  reg  [9:0]                        rd_data_count_d1;

  
  afifo_fwft_w16r32x512 i_afifo_fwft_w16r32x512 (
    .WrClk               (wr_clk),
    .WrReset             (wr_rst),
    .WrEn                (wr_vld_i),
    .Data                (wr_data_i),
    .Full                (full),
    .RdClk               (rd_clk),
    .RdReset             (rd_rst),
    .RdEn                (burst_rd_en),
    .Q                   (burst_rd_data_i),
    .Rnum                (rd_data_count), //10bits
    .Empty               (empty)
  );
    
  assign wr_rdy_o = ~full;
  
  // For better timing
  always @(posedge rd_clk) begin
    rd_data_count_d1 <= rd_data_count;
  end
  
  assign burst_avail = (!empty) & rd_data_count_d1 >= `MEM_WR_BL ? 1'b1 : 1'b0;
  
  assign burst_rd_data = {4'b0, burst_rd_data_i};
  
  // Error
  always@(posedge wr_clk or posedge wr_rst) begin
    if(wr_rst) begin
      err_bfifo_full <= 1'b0;
    end else if(full & wr_vld_i) begin
      err_bfifo_full <= 1'b1;
      `ifdef SIM_ENABLE
        $display ("ERROR: Write Burst FIFO full error..!");
        $stop;
      `endif
    end      
  end
  
endmodule
`default_nettype wire