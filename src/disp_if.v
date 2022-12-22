`default_nettype none

`include "defines.v"
module disp_if (
  // Control
  disp_bars,
  disp_busy,
  disp_cam,
  // Upstream Interface
  rst,
  clk,
  disp_fifo_rdy,
  burst_vld,
  burst_rd_data,
  // Downstream Interface
  disp_clk,
  disp_clk_180,
  disp_rst,
  mclk,
  hsync_n,
  vsync_n,
  href,
  data,
  disp_fifo_underrun,
  disp_fifo_overrun
);
  
  // Control
  input  wire                       disp_bars;
  input  wire                       disp_busy;
  input  wire                       disp_cam;
  // Upstream Interface
  input  wire                       rst;
  input  wire                       clk;
  output wire                       disp_fifo_rdy;
  input  wire                       burst_vld;
  input  wire [`DSIZE-1:0]          burst_rd_data;
  // Display Interface  
  input  wire                       disp_clk;     // 27Mhz
  input  wire                       disp_clk_180; // 27Mhz 180deg shifted
  input  wire                       disp_rst;
  output wire                       mclk;
  output wire                       hsync_n;
  output wire                       vsync_n;
  output wire                       href;
  output wire [`DISP_DSIZE-1:0]     data;
  output wire                       disp_fifo_underrun;
  output reg                        disp_fifo_overrun;
  
  // Local Parameters
  localparam  IDLE                = 5'b0_0001;
  localparam  BAR_PAT             = 5'b0_0010;
  localparam  BUSY_PAT            = 5'b0_0100;
  localparam  CAM_PAT             = 5'b0_1000;
  localparam  DISP_ERR            = 5'b1_0000;
  
  // Internal Signals
  reg  [4:0]                        c_state;
  reg  [4:0]                        n_state;
  wire                              fifo_rd_en;
  wire [`DSIZE-1:0]                 fifo_rd_data;
  wire                              fifo_empty;
  wire                              rfifo_full;
  wire                              rfifo_afull;
  reg                               rfifo_afull_n_d1;
  wire                              rfifo_wr_en;
  wire [9:0]                        rfifo_rd_cnt;
  wire                              dc_data_vld;
  wire                              rd_err;
  wire                              wr_err;
  wire                              sync_sig_en;
  wire [`DISP_DSIZE-1:0]            dc_data;
  wire [`DISP_DSIZE-1:0]            disp_pat;
  reg                               disp_cam_d1;
  reg                               disp_cam_sync;
  reg                               disp_busy_d1;
  reg                               disp_busy_sync;
  reg                               disp_bars_d1;
  reg                               disp_bars_sync;
  reg                               vsync_n_d1;
  reg                               lch_disp_on;
  wire                              vsync_n_fe;
  wire                              en_lch_disp_on;
  wire                              en_lch_pat;
  wire                              flush_cam;
  wire                              dc_sof;
  wire                              dc_eof;
  wire                              any_pat_en;
  wire                              disp_grey;
  wire                              lch_disp_bars;
  wire                              lch_disp_grey;
  reg                               data_cntr;
  
  assign disp_fifo_rdy = ~rfifo_afull;
  
  assign rfifo_wr_en = disp_fifo_rdy && burst_vld;
  
  //================================================
  //*** System Clock Domain
  //================================================
  afifo_fwft_36x512 i_disp_fifo_36x512 (
    .WrClk               (clk),
    .WrReset             (rst),
    .WrEn                (rfifo_wr_en),
    .Data                (burst_rd_data),
    .Almost_Full         (rfifo_afull),
    .Full                (rfifo_full),
    .RdClk               (disp_clk),
    .RdReset             (disp_rst),
    .RdEn                (fifo_rd_en),
    .Q                   (fifo_rd_data),
    .Rnum                (rfifo_rd_cnt),
    .Empty               (fifo_empty) 
  );

  //*** Display Clock Domain
  
  //================================================
  // Data Conversion 32bit to 16bit
  //================================================
  //*** Capture Data conversion 32 to 16
   
  assign dc_data_vld = !fifo_empty || data_cntr != 1'b0 ? 1'b1 : 1'b0;

  // discard data up to start of frame
  assign flush_cam = (c_state != CAM_PAT) && (fifo_rd_data[32] != 1'b1);
  assign fifo_rd_en  = !fifo_empty && (data_cntr == 1'b1 || flush_cam);

  always @(posedge disp_clk) begin
    if (disp_rst) begin
      data_cntr <= 1'b0;
    end else if (dc_data_vld & href) begin
      data_cntr <= data_cntr + 1'b1;
    end
  end

  assign dc_data = data_cntr == 1'b0 ? fifo_rd_data[15:0] :
                                       fifo_rd_data[31:16];
  
  assign dc_sof    = dc_data_vld && data_cntr == 1'b0 ? fifo_rd_data[32] : 1'b0;
  assign dc_eof    = dc_data_vld && data_cntr == 1'b1 ? fifo_rd_data[33] : 1'b0;
  
  //================================================
  //*** Display Clock Domain
  //================================================  
  always@(posedge disp_clk or posedge disp_rst) begin
    if (disp_rst) begin
      vsync_n_d1 <= 1'b1;
    end else begin
      vsync_n_d1 <= vsync_n;
    end
  end
  
  assign vsync_n_fe = (!vsync_n) & vsync_n_d1;  
  
  //================================================
  // Display control fsm
  //================================================   
  // Sequential block
  always @(posedge disp_clk) begin
    if (rst) begin
      c_state <= IDLE;
    end else begin
      c_state <= n_state;
    end
  end

  // Combinational block
  always @(*) begin
    case (c_state)
      IDLE:
        if (disp_bars_sync) begin
          n_state = BAR_PAT;
        end else if (disp_cam_sync & dc_sof) begin
          n_state = CAM_PAT;
//        end else if (disp_busy_sync) begin
//          n_state = BUSY_PAT;
        end else begin
          n_state = BUSY_PAT;
        end
      
      BAR_PAT: 
        if (!disp_busy_sync & vsync_n_fe) begin
          n_state = IDLE;
        end else begin
          n_state = BAR_PAT;
        end
      
      BUSY_PAT: 
        if (!disp_busy_sync & vsync_n_fe) begin
          n_state = IDLE;
        end else begin
          n_state = BUSY_PAT;
        end
        
      CAM_PAT: 
        if (!disp_cam_sync & vsync_n_fe) begin
          n_state = IDLE;
        end else if (rd_err) begin
          n_state = DISP_ERR;
        end else begin
          n_state = CAM_PAT;
        end
        
      DISP_ERR: 
        n_state = DISP_ERR;
        
      default: n_state = IDLE;
    endcase
  end
  
  assign sync_sig_en = (c_state == BAR_PAT || c_state == BUSY_PAT || c_state == CAM_PAT) ? 1'b1 : 1'b0;
  assign lch_disp_grey = c_state == BUSY_PAT ? 1'b1 : 1'b0;
  assign lch_disp_bars = c_state == BAR_PAT ? 1'b1 : 1'b0;
  
  //================================================
  // Data Conversion 32bit to 16bit
  //================================================  
  disp_sync_gen i_disp_sync_gen (
    .clk                 (disp_clk           ),
    .rst                 (disp_rst           ),
    .enable              (sync_sig_en        ),
    .disp_grey           (lch_disp_grey      ),
    .disp_bars           (lch_disp_bars      ),
    .data                (disp_pat           ),
    .hs_n                (hsync_n            ),
    .vs_n                (vsync_n            ),
    .de                  (href               )
  );
  
  assign data = !sync_sig_en                                ? {`DISP_DSIZE{1'b0}} : // OFF
                (c_state == BAR_PAT || c_state == BUSY_PAT) ? disp_pat :            // Test patterns
                                                              dc_data;              // Camera pattern
  
  // 180 degree phase shifted clock for display
  assign mclk = disp_clk_180;
//  CLKDIV2 i_clkdiv2 (
//   .HCLKIN               (disp_clk  ),
//   .RESETN               (~disp_rst ),
//   .CLKOUT               (mclk      )
//   );
  
  
  //================================================
  // Only for debug
  //================================================  
  assign rd_err = disp_cam_sync & (!dc_data_vld) & href;
  assign disp_fifo_underrun = c_state == DISP_ERR ? 1'b1 : 1'b0;
  
  // Only for simulation
  always@(*) begin
    if(disp_fifo_underrun) begin
      $display ("ERROR: No data in FIFO during DE..!");
      $stop;
    end      
  end
  
  assign wr_err = rfifo_full & rfifo_wr_en;
  
  always@(posedge clk) begin
    if(rst) begin
      disp_fifo_overrun <= 1'b0;
    end else if(wr_err) begin
      disp_fifo_overrun <= 1'b1;
      $display ("ERROR: Display FIFO Overflow..!");
      $stop;
    end      
  end
  
  // Synchronize Display control bit
  always@(posedge disp_clk) begin
    disp_cam_d1    <= disp_cam;
    disp_cam_sync  <= disp_cam_d1;
    
    disp_busy_d1   <= disp_busy;
    disp_busy_sync <= disp_busy_d1;
    
    disp_bars_d1   <= disp_bars;
    disp_bars_sync <= disp_bars_d1;
  end
endmodule

`default_nettype wire