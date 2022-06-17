`default_nettype none

`include "defines.v"

module rd_burst_sfifo (
  // Upstream
  rst,
  clk,
  afull,
  wr_en,
  wr_data,
  // Downstream
  ds_rdy,
  burst_vld,
  burst_rd_data,
  err_bfifo_full
);
  
  // Upstream Interface
  input  wire                       rst;
  input  wire                       clk;
  output wire                       afull;
  input  wire                       wr_en;
  input  wire [`DSIZE-1:0]          wr_data;
  // Downstream Interface
  input  wire                       ds_rdy;
  output wire                       burst_vld;
  output wire [`DSIZE-1:0]          burst_rd_data;
  output reg                        err_bfifo_full;

  // Local Parameters
  
  // Internal Signals
  wire                              full;
  wire                              empty;

  
  fifo_fwft_36x512 i_fifo_fwft_36x512 (
    .Clk                  (clk),
    .Reset                (rst),
    .WrEn                 (wr_en),
    .Data                 (wr_data),
    .Almost_Full          (afull),
    .Full                 (full),
    .RdEn                 (ds_rdy),
    .Q                    (burst_rd_data),
    .Empty                (empty)
  );
  
//  fifo_fwft_36x1024 i_fifo_fwft_36x1024 (
//    .Clk                  (clk),
//    .Reset                (rst),
//    .WrEn                 (wr_en),
//    .Data                 (wr_data),
//    .Almost_Full          (afull),
//    .Full                 (full),
//    .RdEn                 (ds_rdy),
//    .Q                    (burst_rd_data),
//    .Empty                (empty),
//    .Wnum                 (),
//    .Almost_Empty         ()
//  );

  assign burst_vld = ~empty;
  
  // Error
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      err_bfifo_full <= 1'b0;
    end else if(full & wr_en) begin
      err_bfifo_full <= 1'b1;
      `ifdef SIM_ENABLE
        $display ("ERROR: Read Burst sFIFO full error..!");
        $stop;
      `endif
    end      
  end
  
endmodule
`default_nettype wire