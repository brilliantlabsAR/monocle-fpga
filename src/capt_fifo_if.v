`default_nettype none

`include "defines.v"
module capt_fifo_if (
  rst,
  clk,
  cfifo_afull, // Programmable full
  cfifo_wr_en,
  cfifo_wr_data,
  clk_reg,
  rst_reg,
  clr_chksm,
  resume_fill,
  cfifo_rd_vld,
  cfifo_rd_en,
  cfifo_rd_cnt,
  cfifo_rd_data,
  sob,
  eob,
  capt_byte_cntr,
  capt_frm_chk_sum,
  capt_fifo_underrun,
  capt_fifo_overrun
);
  
  // Upstream Interface
  input  wire                       rst;
  input  wire                       clk;
  output wire                       cfifo_afull;
  input  wire                       cfifo_wr_en;
  input  wire [`DSIZE-1:0]          cfifo_wr_data;
  // Capture Interface  
  input  wire                       clk_reg;
  input  wire                       rst_reg;
  input  wire                       clr_chksm;
  input  wire                       resume_fill;
  output wire                       cfifo_rd_vld;
  input  wire                       cfifo_rd_en;
  output wire [11:0]                cfifo_rd_cnt;
  output wire [`REG_SIZE-1:0]       cfifo_rd_data/* synthesis syn_keep=1 */;
  output wire                       sob;
  output wire                       eob;
  output reg  [31:0]                capt_byte_cntr;
  output wire [15:0]                capt_frm_chk_sum;
  output reg                        capt_fifo_underrun;
  output reg                        capt_fifo_overrun;
  
  wire                              fifo_rd_en;
  wire [`DSIZE-1:0]                 fifo_rd_data;
  wire [9:0] 			    fifo_rd_cnt;
  wire                              cfifo_aempty;
  wire                              cfifo_empty;
  wire                              dc_rdy;
  wire                              cfifo_full;
  wire                              chk_data_vld;
  wire [15:0]                       chk_data;
  reg                               clr_chksm_d1;
  reg                               clr_chksm_d2;
  reg                               clr_chksm_d3;
  wire                              clr_chksm_sync_re;
  wire                              chk_sum_rst;
  wire [2:0]                        dc_eof_sb;
  wire                              dc_sof;
  wire                              chk_data_vld_i;
  reg  [1:0]                        rd_data_cntr;
  reg                               chk_data_cntr;
  reg                               resume_fill_d1;
  wire                              resume_re;
  
  //================================================
  //*** System Clock Domain
  //================================================
  // Capture FIFO
  afifo_fwft_36x512 i_capt_fifo_36x512 (
    .WrClk               (clk),
    .WrReset             (rst),
    .WrEn                (cfifo_wr_en),
    .Data                (cfifo_wr_data),
    .Almost_Full         (cfifo_afull),
    .Full                (cfifo_full),
    .RdClk               (clk_reg),
    .RdReset             (rst_reg),
    .RdEn                (fifo_rd_en),
    .Q                   (fifo_rd_data),
    .Rnum                (fifo_rd_cnt),
    .Empty               (cfifo_empty) 
  );

   
  //================================================
  //*** Register Clock Domain
  //================================================
  always@(posedge clk_reg) begin
    resume_fill_d1 <= resume_fill;
  end
  
  assign resume_re = resume_fill & (!resume_fill_d1);

  assign fifo_rd_en     = !cfifo_empty && rd_data_cntr == 2'b11 && cfifo_rd_en ? 1'b1 :1'b0;
  assign cfifo_rd_vld   = !cfifo_empty || rd_data_cntr != 2'b00 ? 1'b1 : 1'b0;

  //*** Data conversion
  always @(posedge clk_reg) begin
    if (rst_reg) begin
      rd_data_cntr <= 2'b0;
    end else if (cfifo_rd_vld & cfifo_rd_en) begin
      rd_data_cntr <= rd_data_cntr + 2'b1;
    end
  end
  
  //*** Convert 32 to 8
  assign cfifo_rd_data = rd_data_cntr == 2'b00 ? fifo_rd_data[0+:8]  :
                         rd_data_cntr == 2'b01 ? fifo_rd_data[8+:8]  :
                         rd_data_cntr == 2'b10 ? fifo_rd_data[16+:8] :
                                                 fifo_rd_data[24+:8] ;

  assign cfifo_rd_cnt = { fifo_rd_cnt, 2'b00 } - rd_data_cntr;
   
  
  //*** Convert 32 to 16
  assign chk_data = rd_data_cntr[1] == 1'b0 ? fifo_rd_data[15:0] :
                                              fifo_rd_data[31:16];
  
  assign chk_data_vld = cfifo_rd_vld & cfifo_rd_en && rd_data_cntr[0] == 1'b1 ? 1'b1 : 1'b0;
  
  // Sidebands
  assign sob = cfifo_rd_vld && rd_data_cntr == 2'b00 ? fifo_rd_data[34] : 1'b0;
  assign dc_eof_sb = cfifo_rd_vld && rd_data_cntr == 2'b11 ? fifo_rd_data[35:33] : 1'b0;
  assign eob = dc_eof_sb;
  
  //// Latch the capture status
  //always@(posedge clk_reg) begin
  //  if(rst_reg) begin
  //    eob <= 1'b0;
  //  end else if(resume_re) begin
  //    eob <= 1'b0;
  //  end else if(dc_eof_sb[2]) begin
  //    eob <= 1'b1;
  //  end
  //end
   
  always @(posedge clk_reg) begin
    if (rst_reg || chk_sum_rst)begin// || dc_eof_sb[0] || dc_eof_sb[1] || dc_eof_sb[2]) begin
      capt_byte_cntr <= 0;
    end else if (cfifo_rd_vld && cfifo_rd_en) begin
      capt_byte_cntr <= capt_byte_cntr + 1;
    end
  end
  
  // Synchronize and make pulse
  always@(posedge clk_reg) begin
    if (rst_reg) begin
      clr_chksm_d1 <= 1'b0;
      clr_chksm_d2 <= 1'b0;
      clr_chksm_d3 <= 1'b0;
    end else begin
      clr_chksm_d1 <= clr_chksm;
      clr_chksm_d2 <= clr_chksm_d1;
      clr_chksm_d3 <= clr_chksm_d2;
    end
  end
  
  assign clr_chksm_sync_re = clr_chksm_d2 && (!clr_chksm_d3);
  assign chk_sum_rst = clr_chksm_sync_re;
  
  chk_sum_16 i_capt_chk_sum_16 (
    .rst                 (rst_reg            ),
    .clk                 (clk_reg            ),
    .chk_sum_rst         (chk_sum_rst        ),
    .enable              (chk_data_vld       ),
    .data                (chk_data           ),
    .chk_sum             (capt_frm_chk_sum   )
  );

  //================================================
  //*** Error Status
  //================================================
  // Write Error
  always@(posedge clk) begin
    if(rst) begin
      capt_fifo_overrun <= 1'b0;
    end else if(cfifo_full & cfifo_wr_en) begin
      capt_fifo_overrun <= 1'b1;
      $display ("ERROR: Write request when Capture FIFO is full..!");
      $stop;
    end
  end
  
  // Read Error
  always@(posedge clk_reg) begin
    if(rst_reg || chk_sum_rst) begin
      capt_fifo_underrun <= 1'b0;
    end else if(cfifo_empty && fifo_rd_en) begin
      capt_fifo_underrun <= 1'b1;
      $display ("ERROR: Read request when Capture FIFO is empty..!");
      $stop;
    end
  end
endmodule

`default_nettype wire