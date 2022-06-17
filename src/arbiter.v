`default_nettype none

`include "defines.v"
module arbiter (
  rst,
  clk,
  resume_fill,
  rd_audio,
  capt_audio,
  capt_video,
  capt_frm,
  capt_en,
  discard_cbuf,
  rep_rate_control,
  en_mic,
  en_zoom,
  en_luma_cor,
  sel_zoom_mode,
  // Video Upstream Interface
  v_burst_avail,
  v_rd_en,
  v_rd_data,
  // Audio Upstream Interface
  a_burst_avail,
  a_rd_en,
  a_rd_data,
  // Memory Interface
  mem_addr,
  mem_cmd, //1-Wr 0-Rd
  mem_cmd_en,
  mem_wr_data,
  mem_wr_en,
  mem_cmd_rdy,
  mem_rd_data,
  mem_rd_data_valid,
  mem_data_mask,
  mem_burst_num,
  // Display FIFO Interface
  o_rpl_2x_done,
  disp_avail,
  rfifo_full, // Programmable full
  rfifo_wr_en,
  rfifo_wr_data,
  rd_ctrl_req,
  rd_ctrl_data,
  // Capture FIFO Interface
  c_frm_len,
  c_sel_zoom_mode,
  c_en_zoom,
  c_en_luma_cor,
  c_rd_video_buf,
  c_rd_frm_buf,
  c_rd_audio_buf,
  c_buf_size,
  cfifo_afull, // Programmable full
  cfifo_wr_en,
  cfifo_wr_data,
  dbg_mrb_err
);
  
  
  //  `include "apsaram_param.v"
  //`include "./../synth_mk9b/src/apm256/apsram_param.v"
  //`include "./../synth_mk9b/src/apm256/apsram_local_param.v"
  
  parameter MEM_SIZE               = 32 * 1024 * 1024;
  parameter DQ_WIDTH               = 8;//8,16,...
  parameter PSRAM_WIDTH            = 8;//8,16
  parameter Fixed_Latency_Enable   = "Fixed";//"Unfixed"
  parameter RL                     = "6";//"3","4","5","6","7"
  parameter Drive_Strength         = "1/2";//"Full","1/2","1/4","1/8"
  parameter PASR                   = "full";//bottom_1/2,bottom_1/4,bottom_1/8,none,top_1/2,top_1/4,top_1/8
  parameter ADDR_WIDTH             = 25;//X8 == 25,X16 == 24
  parameter WL                     = "6";//"3","4","5","6","7"
  parameter Refresh_Rate           = "4X";// "4X","1X","0.5X"
  parameter Power_Down             = "None";//"None", "Half_Sleep","Deep_Power_Down"
  parameter DQ_MODE                = "X8";//"X8","X16"
  parameter RBX                    = "OFF";//"OFF","ON"
  parameter Burst_Type             = "Word_Wrap";//"Word_Wrap","Hybrid_Wrap"
  parameter Burst_Length           = "2K_Byte"; //"16_Byte","32_Byte","64_Byte","2K_Byte"
  localparam  RWDS_WIDTH = DQ_WIDTH/PSRAM_WIDTH;
  localparam  CS_WIDTH   = DQ_WIDTH/PSRAM_WIDTH;
  localparam  MASK_WIDTH = (4*DQ_WIDTH)/(PSRAM_WIDTH*CS_WIDTH);
  
  // Camera Interface
  input  wire                       rst;
  input  wire                       clk;
  input  wire                       resume_fill;
  input  wire                       rd_audio;
  input  wire                       capt_audio;
  input  wire                       capt_video;
  input  wire                       capt_frm;
  input  wire                       capt_en;
  input  wire                       discard_cbuf;
  input  wire [4:0]                 rep_rate_control;
  input  wire                       en_mic;
  input  wire                       en_zoom;
  input  wire                       en_luma_cor;
  input  wire [1:0]                 sel_zoom_mode;
  // Video Upstream Interface
  input  wire                       v_burst_avail;
  output reg                        v_rd_en;
  input  wire [`DSIZE-1:0]          v_rd_data;
  // Audio Upstream Interface
  input  wire                       a_burst_avail;
  output reg                        a_rd_en;
  input  wire [`DSIZE-1:0]          a_rd_data;
  // Memory Interface
  output reg  [ADDR_WIDTH-1:0]      mem_addr;
  output reg                        mem_cmd; //1-Wr 0-Rd
  output reg                        mem_cmd_en;
  output wire [4*DQ_WIDTH-1:0]      mem_wr_data;
  output reg                        mem_wr_en;
  input  wire                       mem_cmd_rdy;
  input  wire [4*DQ_WIDTH-1:0]      mem_rd_data;
  input  wire                       mem_rd_data_valid;
  output reg  [CS_WIDTH*MASK_WIDTH-1:0] mem_data_mask;
  output wire [9:0]                 mem_burst_num;
  // Display FIFO Interface
  output wire                       o_rpl_2x_done;;
  output wire                       disp_avail;
  input  wire                       rfifo_full;
  output wire                       rfifo_wr_en;
  output wire [`DSIZE-1:0]          rfifo_wr_data;
  input  wire                       rd_ctrl_req;
  output reg  [35:0]                rd_ctrl_data;
  // Capture FIFO Interface
  output wire [23:0]                c_frm_len;
  output wire [1:0]                 c_sel_zoom_mode;
  output wire                       c_en_zoom;
  output wire                       c_en_luma_cor;
  output wire                       c_rd_video_buf;
  output wire                       c_rd_frm_buf;
  output wire                       c_rd_audio_buf;
  output wire [31:0]                c_buf_size;
  input  wire                       cfifo_afull;
  output wire                       cfifo_wr_en;
  output wire [`DSIZE-1:0]          cfifo_wr_data;
  output wire                       dbg_mrb_err;
  
  //output reg                        wfifo_full_err/* synthesis syn_keep=1 */;
    
  // Local Parameters
  localparam  WR_IDLE             = 10'b00_0000_0001;
  localparam  WR_BURST            = 10'b00_0000_0010;
  localparam  RD_IDLE             = 10'b00_0000_0100;
  localparam  RD_BURST            = 10'b00_0000_1000;
  localparam  FRM_CAPT            = 10'b00_0001_0000;
  localparam  AUDIO_WR_BURST      = 10'b00_0010_0000;
  localparam  CAPT_RD_IDLE        = 10'b00_0100_0000;
  
  localparam  BUF_CNTR_WIDTH      = $clog2(`TOTAL_BUF);
  //localparam  BURST_CNTR_WIDTH    = $clog2(`BURST_LEN)+1; //+1 for Read burst only
  localparam  BURST_CNTR_WIDTH    = $clog2(`MEM_WR_BL>`MEM_RD_BL ? `MEM_WR_BL : `MEM_RD_BL)+1; //+1 for Read burst only
  localparam  BUF_ADDR_WIDTH      = $clog2(MEM_SIZE/(`TOTAL_BUF+1)); //+1 for audio
  localparam  FNUM_WIDTH          = $clog2(`MAX_TOTAL_FRM);

  // Internal Signals
  reg  [9:0]                        c_state;
  reg  [9:0]                        n_state;
  wire                              wr_sof;
  wire                              wr_eof;
  wire                              o_rd_sob;
  wire                              o_rd_eob;
  wire                              o_rd_sof;
  wire                              o_rd_eof;  
  wire                              c_rd_sob;
  wire                              c_rd_eob;
  wire                              c_rd_sof;
  wire                              c_rd_eof;
  wire [ADDR_WIDTH:0]               waddr_i;
  wire [ADDR_WIDTH:0]               raddr_i;
  wire                              rd_en_nxt;
  wire                              eob_wr;
  wire                              eob_rd;
  reg  [BURST_CNTR_WIDTH-1:0]       burst_cntr;
  reg  [BURST_CNTR_WIDTH-1:0]       rd_burst_cntr;
  reg  [ADDR_WIDTH-1:0]             w_maddr;
  reg  [ADDR_WIDTH-1:0]             w_maddr_d1;
  wire [ADDR_WIDTH-1:0]             o_maddr_d1;
  wire [ADDR_WIDTH-1:0]             c_maddr_d1;
  wire [ADDR_WIDTH-1:0]             a_maddr_d1;
  reg                               capt_en_d1;
  reg                               capt_en_d2;
  reg                               capt_en_d3;
  reg                               capt_en_d4;
  wire                              capt_en_re;
  reg                               disc_cbuf_d1;
  reg                               disc_cbuf_d2;
  reg                               disc_cbuf_d3;
  reg                               disc_cbuf_d4;
  wire                              disc_cbuf_re;
  wire                              o_disc_buf_ack;
  wire                              c_disc_buf_ack;
  reg                               discard_cbuf_d1;
  reg                               discard_cbuf_sync;
  reg                               resume_fill_d1;
  reg                               resume_fill_d2;
  reg                               resume_fill_d3;
  wire                              resume_fill_re;
  reg                               lch_capt_en;
  wire                              video_capt_sel;
  reg                               video_capt_sel_d1;
  reg                               video_capt_sel_sync;
  wire                              audio_capt_sel;
  reg                               audio_capt_sel_d1;
  reg                               audio_capt_sel_sync;
  reg                               disp_cam_d1;
  reg                               disp_cam_sync;
  reg                               lch_disp_cam;
  wire                              frm_capt_sel;
  reg                               frm_capt_sel_d1;
  reg                               frm_capt_sel_sync;
  wire                              capt_rd_audio;
  reg                               lch_c_rd_buf_done;
  wire                              a_rd_en_nxt;
  wire                              capt_rd_audio_sync;
  reg                               capt_rd_audio_d1;
  wire                              audio_only_capt;
  wire [9:0]                        burst_len;
  wire [35:0]                       zoom_rd_ctrl;
  reg  [35:0]                       sof_lch_zoom_rd_ctrl;
  reg  [`FL_WIDTH-1:0]              w_frm_len;
  reg  [FNUM_WIDTH-1:0]             w_frm_cntr;
  wire [FNUM_WIDTH-1:0]             buf_size_tsh;
  reg  [FNUM_WIDTH-1:0]             w_top_fnum;
  reg  [FNUM_WIDTH-1:0]             n_top_fnum;
  wire [FNUM_WIDTH-1:0]             n_w_fnum;
  wire [FNUM_WIDTH-1:0]             n2n_w_fnum;
  reg  [FNUM_WIDTH-1:0]             w_head_fnum;
  reg                               w_tail_frm; 
  reg  [ADDR_WIDTH-1:0]             w_sof_maddr;
  reg  [ADDR_WIDTH-1:0]             w_top_maddr;
  reg  [ADDR_WIDTH-1:0]             n_top_maddr;
  wire [ADDR_WIDTH:0]               free_mem_bytes;
  wire [ADDR_WIDTH:0]               max_buf_size;
  wire                              mem_has_free_buf;
  wire [71:0]                       fcq_wdata;
  wire [3:0]                        o_zoom_ctrl;
  wire [3:0]                        c_zoom_ctrl;
  reg  [FNUM_WIDTH-1:0]             w_fnum;
  wire                              c_buf_avail;
  wire                              capt_avail;
  wire                              c_bcq_tob_pulse;
  wire                              bcq_wr_en_c;
  wire                              bcq_wr_en_o;
  reg                               bcq_wr_en_c_d1;
  reg                               bcq_wr_en_o_d1;
  wire [71:0]                       bcq_wdata;
  wire                              w_top_frm/* synthesis syn_keep=1 */;
  wire                              w_bot_frm;
  reg                               en_zoom_d1;
  reg                               en_zoom_sync;
  reg                               en_luma_cor_d1;
  reg                               en_luma_cor_sync;
  reg  [1:0]                        sel_zoom_mode_d1;
  reg  [1:0]                        sel_zoom_mode_sync;
  wire [3:0]                        w_zoom_ctrl;
  wire                              o_mem_rd_cmd;
  wire                              c_mem_rd_cmd;
  wire                              o_rd_frm_done;
  wire                              c_rd_frm_done;
  reg                               buf_full;
  wire                              o_mem_rd_vld;
  wire                              c_mem_rd_vld;
  wire                              o_buf_avail;
  wire                              o_frm_avail;
  wire                              c_frm_avail;
  reg                               w_frm_in_progress;
  reg                               lch_frm_capt_en;
  wire                              send_wr_to_tob;
  reg                               c_disc_this_buf;
  reg                               o_disc_this_buf;
  wire                              capturing_frm;
  wire                              fcq_wr_en;
  reg                               wait_for_resume;

  
  
  
  //================================================
  // Extract Sideband
  //================================================
  assign wr_sof  = v_rd_en & v_rd_data[32];
  assign wr_eof  = v_rd_en & v_rd_data[33];
  
  
  //// Derive sideband information
  //reg [16:0] frm_burst_cnt;
  //always@(posedge clk) begin
  //  if(rst | wr_eof)
  //    frm_burst_cnt <= 17'd0;
  //  else if(c_state == WR_BURST)
  //    frm_burst_cnt <= frm_burst_cnt + 17'd1;
  //end
  //
  //assign wr_sof = frm_burst_cnt == 0 ? 1'b1 : 1'b0;
  //assign wr_eof = frm_burst_cnt == (`FRAME_LENGTH>>2)-1 ? 1'b1 : 1'b0;
  
  // Frame Length Counter
  always@(posedge clk) begin
    if(rst || wr_eof) begin
      w_frm_len <= 23'd4;
    end else if(v_rd_en) begin
      w_frm_len <= w_frm_len + 23'd4;
    end
  end
  
  // In progress frame-write
  always@(posedge clk) begin
    if(rst || wr_eof) begin
      w_frm_in_progress <= 1'b0;
    end else if(wr_sof) begin
      w_frm_in_progress <= 1'b1;
    end
  end

  //================================================
  // Circular buffer control
  //================================================
  always@(posedge clk) begin
    if(rst) begin
      w_frm_cntr <= 9'd0;
    end else if(wr_eof) begin
      if (w_bot_frm || w_tail_frm || send_wr_to_tob) begin
        w_frm_cntr <= 9'd0;
      end else begin
        w_frm_cntr <= w_frm_cntr + 9'd1;
      end
    end
  end
  
  assign buf_size_tsh = capturing_frm ? 9'd1 : `MAX_FRM_PER_BUF;

  assign w_top_frm = w_frm_cntr == 9'b0 ? 1'd1 : 1'b0;
  assign w_bot_frm = (!lch_frm_capt_en && w_frm_cntr == (buf_size_tsh - 1)) ? 1'd1 : 1'b0;
  
  always@(posedge clk) begin
    if(rst) begin
      w_sof_maddr <= {ADDR_WIDTH{1'b0}};
    end else if(wr_sof) begin
      w_sof_maddr <= w_maddr_d1;
    end
  end

  always@(posedge clk) begin
    if(rst) begin
      w_top_maddr <= 25'd0;
      w_top_fnum <= 9'd0;
    end else if(w_top_frm && wr_sof) begin
      w_top_maddr <= w_maddr_d1;
      w_top_fnum <= w_fnum;
    end
  end
  
  // Latch Next buffer Top when we see bottom of buffer
  always@(posedge clk) begin
    if(rst) begin
      n_top_maddr <= {`FL_WIDTH{1'b0}};
      n_top_fnum <= 9'd0;
    //end else if((w_bot_frm || (buf_full && w_tail_frm)) && wr_eof) begin
    end else if(w_bot_frm && wr_eof) begin
      n_top_maddr <= w_maddr_d1;
      n_top_fnum <= n_w_fnum;
    end
  end
  
  // Check for incomplete buffer
  always@(posedge clk) begin
    if(rst) begin
      buf_full <= 1'b0;
    end else if(wr_eof) begin
      if(w_tail_frm || send_wr_to_tob) begin
        buf_full <= 1'b0;
      end else if(w_bot_frm) begin
        buf_full <= 1'b1;
      end
    end
  end
  
  assign free_mem_bytes = MEM_SIZE - n_top_maddr;
  assign max_buf_size = frm_capt_sel_sync ? (`HIGH_RES_FL>>2) : `MAX_FRM_PER_BUF*(`FRAME_LENGTH>>2); // >>2 is a compression ratio 1/4
  assign mem_has_free_buf = 1'b1;//free_mem_bytes >= max_buf_size ? 1'b1 : 1'b0;
  
  // Not set for full frame
  // Check if mem has available free buffer, otherwise keep overwritting the current buf
  always @(posedge clk) begin
    if (rst) begin
      w_tail_frm <= 1'b0;
    end else begin
      if (wr_eof) begin
        w_tail_frm <= 1'b0;
      end else if ((video_capt_sel_sync && capt_en_re) || capturing_frm) begin
        w_tail_frm <= 1'b1;
      end
    end
  end
  
  assign n_w_fnum = w_fnum + 9'd1;
  assign n2n_w_fnum = w_fnum + 9'd2;
  
  always @(posedge clk) begin
    if (rst) begin
      w_head_fnum <= 9'b0;
    end else if (w_tail_frm && wr_eof) begin
      if (!capturing_frm && buf_full && w_frm_cntr < `MAX_FRM_PER_BUF-2) begin  // 2nd last frame? Then go to top
        w_head_fnum <= n2n_w_fnum;
      end else begin
        w_head_fnum <= w_top_fnum;
      end
    end
  end
  /////// Start of buffer frame number
  /////assign w_head_fnum = (w_bot_frm || !buf_full) ? w_top_fnum :    //Top of buffer when Rollover Or when capturing incomplete buffer
  /////                                                ((n_w_fnum + 9'd1) >= ? );//Next2Next write buffer, this is to be safe side so that 
  /////                                                                //buffer won't start from overwritten incomplete frame.
  /////                                                                //This is with assumption that in worst case compression is done with 1/2 ratio

  assign w_zoom_ctrl = {en_luma_cor_sync, en_zoom_sync, sel_zoom_mode_sync};

  assign fcq_wr_en = (!wait_for_resume && wr_eof) ? 1'b1 : 1'b0;
  
  assign fcq_wdata = {
                      `ifdef MK11
                      16'b0,       // [56+:17]Reserved
                      `else
                      17'b0,       // [55+:17]Reserved
                      `endif
                      w_sof_maddr, // [30+:ADDR_WIDTH]
                      w_zoom_ctrl, // [26+:4]
                      w_frm_len,   // [2+:`FL_WIDTH]
                      w_tail_frm,  // [1+:1]
                      w_bot_frm};  // [0+:1]
                      
  assign bcq_wdata = {51'b0,               // [21+:51]Reserved
                      video_capt_sel_sync, // [20+:1]
                      frm_capt_sel_sync,   // [19+:1]
                      audio_capt_sel_sync, // [18+:1]
                      w_head_fnum,         // [9+:FNUM_WIDTH]
                      w_top_fnum};         // [0+:FNUM_WIDTH]  
  
  assign bcq_wr_en_c = w_tail_frm & wr_eof;
  assign bcq_wr_en_o = w_tail_frm & wr_eof;

  // Synchronize BCQ write enable with latched write data
  always @(posedge clk) begin
    if (rst) begin
      bcq_wr_en_c_d1 <= 1'b0;
      bcq_wr_en_o_d1 <= 1'b0;
    end else begin
      bcq_wr_en_c_d1 <= bcq_wr_en_c;
      bcq_wr_en_o_d1 <= bcq_wr_en_o;
    end
  end

  //================================================
  // Arbiter FSM
  //================================================
  // Sequential block
  always @(posedge clk) begin
    if (rst) begin
      c_state <= WR_IDLE;
    end else begin
      c_state <= n_state;
    end
  end
  
  // Combinational block
  always @(*) begin
    case (c_state)
      WR_IDLE:
        if (mem_cmd_rdy) begin
          if (a_burst_avail) begin
            n_state = AUDIO_WR_BURST;
          end else if (v_burst_avail) begin
            n_state = WR_BURST;
          end else if (disp_avail) begin
            n_state = RD_IDLE;
          end else if (!cfifo_afull & capt_avail) begin
            n_state = CAPT_RD_IDLE;
          end else begin
            n_state = WR_IDLE;
          end
        end else begin
          n_state = WR_IDLE;
        end
      
      AUDIO_WR_BURST: 
        if (eob_wr) begin
          if (disp_avail) begin
            n_state = RD_IDLE;
          end else begin
            n_state = WR_IDLE;
          end
        end else begin
          n_state = AUDIO_WR_BURST;
        end
      
      WR_BURST: 
        if (eob_wr) begin
          if (disp_avail) begin
            n_state = RD_IDLE;
          end else begin
            n_state = CAPT_RD_IDLE;
          end
        end else begin
          n_state = WR_BURST;
        end
  
      RD_IDLE:
        if (mem_cmd_rdy) begin
          if (!rfifo_full) begin
            n_state = RD_BURST;
          end else begin
            n_state = CAPT_RD_IDLE;
          end
        end else begin
          n_state = RD_IDLE;
        end
       
      RD_BURST:
        if (eob_rd) begin
            n_state = CAPT_RD_IDLE;
          //if (lch_capt_en) begin
          //  n_state = CAPT_RD_IDLE;
          //end else begin
          //  n_state = WR_IDLE;
          //end
        end else begin
          n_state = RD_BURST;
        end
        
      CAPT_RD_IDLE: 
        if (mem_cmd_rdy) begin
          if ((!cfifo_afull) & capt_avail) begin
            n_state = FRM_CAPT;
          end else begin
            n_state = WR_IDLE;
          end
        end else begin
          n_state = CAPT_RD_IDLE;
        end
      
      FRM_CAPT: 
        if (eob_rd) begin
          n_state = WR_IDLE;
        end else begin
          n_state = FRM_CAPT;
        end
            
      default: n_state = WR_IDLE;
    endcase
  end
  
  assign rd_en_nxt = c_state == WR_BURST ? 1'b1 : 1'b0;
  assign a_rd_en_nxt = c_state == AUDIO_WR_BURST ? 1'b1 : 1'b0;
  
  always @(posedge clk) begin
    v_rd_en <= rd_en_nxt;
    a_rd_en <= a_rd_en_nxt;
  end
  
  
  
  //================================================
  // Burst Counters
  //================================================
  assign burst_len = (c_state == WR_BURST | c_state == AUDIO_WR_BURST) ? `MEM_WR_BL : //Write
                                                                         `MEM_RD_BL;  //Read
                                                                             
  // Read/Write burst counter
  always @(posedge clk) begin
    if (rst) begin
      burst_cntr <= {BURST_CNTR_WIDTH{1'b0}};
    end else if (!eob_rd && (c_state == WR_BURST || c_state == AUDIO_WR_BURST || c_state == RD_BURST || c_state == FRM_CAPT)) begin
      if (burst_cntr < mem_burst_num) begin
        burst_cntr <= burst_cntr + 1;
      end
    end else begin
      burst_cntr <= {BURST_CNTR_WIDTH{1'b0}};
    end
  end
  
  always @(posedge clk) begin
    if (rst) begin
      rd_burst_cntr <= {BURST_CNTR_WIDTH{1'b0}};
    end else if(mem_rd_data_valid) begin
      rd_burst_cntr <= rd_burst_cntr + 1;
    end else begin
      rd_burst_cntr <= {BURST_CNTR_WIDTH{1'b0}};
    end
  end
  
  assign eob_wr = burst_cntr    == `MEM_WR_BL-1 ? 1'b1 : 1'b0;
  assign eob_rd = rd_burst_cntr == `MEM_RD_BL-1 ? 1'b1 : 1'b0;
  
  
  
  //================================================
  // Memory Write Address
  //================================================
  // Write Buffer Address
  always @(posedge clk) begin
    if (rst) begin
      w_maddr <= 'd0;
    //end else if(c_state == WR_BURST) begin
    //** NOTE: For non-burst aligned frame lengths, wr_eof must be replaced with correct end of frame
    end else if (wr_eof) begin
      if (wait_for_resume || (!w_tail_frm && (w_bot_frm || send_wr_to_tob))) begin  //Rollover -back to start of the buffer
        w_maddr <= w_top_maddr;
      end else if (!capturing_frm && buf_full && w_tail_frm) begin // Current buf captured, move to next buf
        w_maddr <= n_top_maddr;
      end
    end else if(c_state == WR_BURST && burst_cntr == 'd0) begin
      w_maddr <= w_maddr + (`MEM_WR_BL<<2); //c_waddr + BL*4
    end
  end

  // Pipeline for Better Timing, should not affect functionaly
  always @(posedge clk) begin
    w_maddr_d1 <= w_maddr;
  end
  
  assign a_maddr_d1 = {ADDR_WIDTH{1'b1}};
  
  // Memory Write Address
  assign waddr_i = w_maddr_d1;
  //assign waddr_i = c_state == AUDIO_WR_BURST ? a_maddr_d1 :
  //                                             w_maddr_d1;
  
  // Write Frame counter
  always @(posedge clk) begin
    if (rst) begin
      w_fnum <= {FNUM_WIDTH{1'b0}};
    //end else if(c_state == WR_BURST) begin
      //** NOTE: For non-burst aligned frame lengths, wr_eof must be replaced with correct end of frame
    end else if (wr_eof) begin
      if (wait_for_resume || (!w_tail_frm && (w_bot_frm || send_wr_to_tob))) begin  //Rollover -back to start of the buffer
        w_fnum <= w_top_fnum;
      end else if (capturing_frm) begin // This is frame capture, so next buf top is cur+1
        w_fnum <= n_w_fnum;
      end else if (buf_full && w_tail_frm) begin // Current full buf captured, move to next buf top
        w_fnum <= n_top_fnum;
      end else begin
        w_fnum <= n_w_fnum;
      end
    end
  end


  //================================================
  // Memory Read Address
  //================================================
  assign o_mem_rd_cmd = burst_cntr == 'd0 && c_state == RD_BURST ? 1'b1 : 1'b0;
  assign o_mem_rd_vld  = (c_state == RD_BURST) & mem_rd_data_valid ? 1'b1 : 1'b0;
  assign o_rd_frm_done = o_mem_rd_vld && o_rd_eof ? 1'b1 : 1'b0;

  assign rfifo_wr_en   = o_mem_rd_vld;
  assign rfifo_wr_data = {2'b00, o_rd_eof, o_rd_sof, mem_rd_data};
  
  mem_rd_ctrl #(
    .CAPT_CNTRL_SEL       (0),
    .ADDR_WIDTH           (ADDR_WIDTH),
    .FNUM_WIDTH           (FNUM_WIDTH)
  ) i_mem_rd_ctrl_oled (
    .rst                  (rst),
    .clk                  (clk),
    .rpt_rate_ctrl        (rep_rate_control),
    .fcq_wr_addr          (w_fnum),
    .fcq_wr_en            (fcq_wr_en),
    .fcq_wdata            (fcq_wdata),
    .fcq_rd_en            (o_rd_frm_done),
    .disc_this_buf        (o_disc_this_buf),
    .disc_buf_ack         (o_disc_buf_ack),
    .send_wr_to_tob       (send_wr_to_tob),
    .capturing_frm        (capturing_frm),
    .buf_full             (buf_full),
    .r_zoom_ctrl          (o_zoom_ctrl),
    .r_frm_len            (), //For Internal use
    .bcq_wr_en            (bcq_wr_en_o_d1),
    .bcq_wdata            (bcq_wdata),
    .bcq_tob_pulse        (), //For Internal use
    .buf_size             (),
    .mem_rd_cmd           (o_mem_rd_cmd),
    .mem_rd_vld           (o_mem_rd_vld),
    .rpl_2x_done          (o_rpl_2x_done),
    .buf_avail            (o_buf_avail),
    .frm_avail            (o_frm_avail),
    .r_maddr_d1           (o_maddr_d1),
    .rd_video_buf         (),
    .rd_frm_buf           (),
    .rd_audio_buf         (),
    .rd_sob               (),
    .rd_eob               (),
    .rd_sof               (o_rd_sof),
    .rd_eof               (o_rd_eof),
	.dbg_mrb_err          (dbg_mrb_err)
  );
  assign disp_avail = o_buf_avail;// || (lch_disp_cam && o_frm_avail);

  assign c_mem_rd_cmd = burst_cntr == 'd0 && c_state == FRM_CAPT ? 1'b1 : 1'b0;
  assign c_mem_rd_vld  = (c_state == FRM_CAPT) & mem_rd_data_valid ? 1'b1 : 1'b0;
  assign c_rd_frm_done = c_mem_rd_vld && c_rd_eof ? 1'b1 : 1'b0;
  
  assign cfifo_wr_en   = c_mem_rd_vld;
  assign cfifo_wr_data = {c_rd_eob, c_rd_sob, c_rd_eof, c_rd_sof, mem_rd_data};
  
  mem_rd_ctrl #(
    .CAPT_CNTRL_SEL       (1),
    .ADDR_WIDTH           (ADDR_WIDTH),
    .FNUM_WIDTH           (FNUM_WIDTH)
  ) i_mem_rd_ctrl_capt (
    .rst                  (rst),
    .clk                  (clk),
    .rpt_rate_ctrl        (5'd1),
    .fcq_wr_addr          (w_fnum),
    .fcq_wr_en            (fcq_wr_en),
    .fcq_wdata            (fcq_wdata),
    .fcq_rd_en            (c_rd_frm_done),
    .disc_this_buf        (c_disc_this_buf),
    .disc_buf_ack         (c_disc_buf_ack),
    .send_wr_to_tob       (send_wr_to_tob),
    .capturing_frm        (capturing_frm),
    .buf_full             (buf_full),
    .r_zoom_ctrl          (c_zoom_ctrl),
    .r_frm_len            (c_frm_len),
    .bcq_wr_en            (bcq_wr_en_c_d1),
    .bcq_wdata            (bcq_wdata),
    .bcq_tob_pulse        (c_bcq_tob_pulse),
    .buf_size             (c_buf_size),
    .mem_rd_cmd           (c_mem_rd_cmd),
    .mem_rd_vld           (c_mem_rd_vld),
    .rpl_2x_done          (),
    .buf_avail            (c_buf_avail),
    .frm_avail            (c_frm_avail),
    .r_maddr_d1           (c_maddr_d1),
    .rd_video_buf         (c_rd_video_buf),
    .rd_frm_buf           (c_rd_frm_buf),
    .rd_audio_buf         (c_rd_audio_buf),
    .rd_sob               (c_rd_sob),
    .rd_eob               (c_rd_eob),
    .rd_sof               (c_rd_sof),
    .rd_eof               (c_rd_eof),
	.dbg_mrb_err          ()
  );
  assign capt_avail = c_buf_avail;// && ble_en_sync; //ble_en_sync=If BLE is not connected and MCU need to discard the captured buffer,
                                                     //            then MCU need to inform FPGA in advance. This is to know whether start
                                                     //            buffering the captured buffer data into local buffer or not.
  
  assign c_sel_zoom_mode = c_zoom_ctrl[1:0];
  assign c_en_zoom       = c_zoom_ctrl[2];// & dbg_mrb_err; // Remove dbg_mrb_err after Testing
  assign c_en_luma_cor   = c_zoom_ctrl[3];
  
  always @(posedge clk) begin
    if (rst) begin
      lch_c_rd_buf_done <= 1'b0;
    end else begin
      if (resume_fill_re) begin
        lch_c_rd_buf_done <= 1'b0;
      end else if (c_bcq_tob_pulse) begin
        lch_c_rd_buf_done <= 1'b1;
      end
    end
  end
  
  assign raddr_i = c_state == FRM_CAPT ? c_maddr_d1 : /*(capt_rd_audio_sync ? a_maddr_d1 :  // Audio capture read
                                                               c_maddr_d1) :*/ // Video capture read
                                         o_maddr_d1;
  

  
  assign zoom_rd_ctrl = {32'b0, o_zoom_ctrl};
  
  // Need to latch control information at Arbiter SOF to compensate latency between Arbiter and Luma/Zoom
  always @(posedge clk) begin
    if (rst) begin
      sof_lch_zoom_rd_ctrl <= 36'b0;
    end else begin
      if (o_rd_sof) begin
        sof_lch_zoom_rd_ctrl <= zoom_rd_ctrl;
      end
    end
  end
  
  // Latch again on Luma/Zoom EOF
  always @(posedge clk) begin
    if (rst) begin
      rd_ctrl_data <= 36'b0;
    end else begin
      if (rd_ctrl_req) begin // Luma/Zoom EOF
        rd_ctrl_data <= sof_lch_zoom_rd_ctrl;
      end
    end
  end

  
  
  //================================================
  // Memory Control
  //================================================
  always @(posedge clk) begin
    if (rst) begin
      mem_cmd         <= 1'b0;
      mem_cmd_en      <= 1'b0;
      mem_addr        <=  'b0;
      mem_wr_en       <= 1'b0;
      //mem_wr_data     <=  'b0;
      mem_data_mask   <=  'b0;
    end else if ((burst_cntr == 'd0) && (c_state == WR_BURST | c_state == AUDIO_WR_BURST)) begin
      mem_cmd         <= 1'b1;
      mem_cmd_en      <= 1'b1;
      mem_addr        <= waddr_i[ADDR_WIDTH-1:0];
      mem_wr_en       <= 1'b1;
      //mem_wr_data     <= v_rd_data;              
      mem_data_mask   <=  'b0;
    end else if ((burst_cntr !== 'd0) && (c_state == WR_BURST | c_state == AUDIO_WR_BURST)) begin
      mem_cmd         <= 1'b0;
      mem_cmd_en      <= 1'b0;
      mem_addr        <=  'b0;
      mem_wr_en       <= 1'b1;
      //mem_wr_data     <= v_rd_data;              
      mem_data_mask   <=  'b0; 
    end else if ((burst_cntr == 'd0) && (c_state == RD_BURST | c_state == FRM_CAPT)) begin
      mem_cmd         <= 1'b0;
      mem_cmd_en      <= 1'b1;
      mem_wr_en       <= 1'b0;
      mem_addr        <= raddr_i[ADDR_WIDTH-1:0];
      mem_data_mask   <=  'b0;
    end else begin
      mem_cmd         <= 1'b0;
      mem_cmd_en      <= 1'b0;
      mem_addr        <=  'b0;
      mem_wr_en       <= 1'b0;
      //mem_wr_data     <=  'b0;
      mem_data_mask   <=  'b0;
    end
  end
  
  assign mem_wr_data   = a_rd_en ? a_rd_data : v_rd_data;
  assign mem_burst_num = burst_len-1;
  //assign mem_burst_num = `BURST_LEN-1;

  //================================================
  // Synchronize Control Signal
  //================================================
  always @(posedge clk) begin
    if (rst) begin
      capt_en_d1 <= 1'b0;
      capt_en_d2 <= 1'b0;
      capt_en_d3 <= 1'b0;
      capt_en_d4 <= 1'b0;
    end else begin
      capt_en_d1 <= capt_en;
      capt_en_d2 <= capt_en_d1;
      capt_en_d3 <= capt_en_d2;
      capt_en_d4 <= capt_en_d3;
    end
  end
  
  // Rising edge detection
  assign capt_en_re = (!capt_en_d4) & capt_en_d3;

  assign frm_capt_sel   = capt_frm;
  assign video_capt_sel = capt_video;
  assign audio_capt_sel = capt_audio;

  assign capt_rd_audio = rd_audio;

  always @(posedge clk) begin
    if (rst) begin
      disc_cbuf_d1 <= 1'b0;
      disc_cbuf_d2 <= 1'b0;
      disc_cbuf_d3 <= 1'b0;
      disc_cbuf_d4 <= 1'b0;
    end else begin
      disc_cbuf_d1 <= discard_cbuf;
      disc_cbuf_d2 <= disc_cbuf_d1;
      disc_cbuf_d3 <= disc_cbuf_d2;
      disc_cbuf_d4 <= disc_cbuf_d3;
    end
  end
  
  // Rising edge detection
  assign disc_cbuf_re = (!disc_cbuf_d4) & disc_cbuf_d3;

  always @(posedge clk) begin
    frm_capt_sel_d1   <= frm_capt_sel;
    frm_capt_sel_sync <= frm_capt_sel_d1;
    
    video_capt_sel_d1   <= video_capt_sel;
    video_capt_sel_sync <= video_capt_sel_d1;
    
    audio_capt_sel_d1   <= audio_capt_sel;
    audio_capt_sel_sync <= audio_capt_sel_d1;

    discard_cbuf_d1 <= discard_cbuf;
    discard_cbuf_sync <= discard_cbuf_d1;
  end

  assign audio_only_capt = !video_capt_sel_sync && audio_capt_sel_sync;
  assign capt_rd_audio_sync = (audio_only_capt || (!audio_only_capt && lch_c_rd_buf_done)) ? 1'b1 : 1'b0;
  
  always @(posedge clk) begin
    en_zoom_d1   <= en_zoom;
    en_zoom_sync <= en_zoom_d1;
    
    en_luma_cor_d1   <= en_luma_cor;
    en_luma_cor_sync <= en_luma_cor_d1;
    
    sel_zoom_mode_d1   <= sel_zoom_mode;
    sel_zoom_mode_sync <= sel_zoom_mode_d1;
  end
    
//  // Capture Read Control
//  always @(posedge clk) begin
//    if (rst) begin
//      capt_rd_audio_d1   <= 1'b0;
//      capt_rd_audio_sync <= 1'b0;
//    end else begin
//      capt_rd_audio_d1   <= capt_rd_audio;
//      capt_rd_audio_sync <= capt_rd_audio_d1;
//    end
//  end
      
  always @(posedge clk) begin
    if (rst) begin
      resume_fill_d1 <= 1'b0;
      resume_fill_d2 <= 1'b0;
      resume_fill_d3 <= 1'b0;
    end else begin
      resume_fill_d1 <= resume_fill;
      resume_fill_d2 <= resume_fill_d1;
      resume_fill_d3 <= resume_fill_d2;
    end
  end

  // Rising edge detection
  assign resume_fill_re = (!resume_fill_d3) & resume_fill_d2;

//  // Latch dispaly camera using read EOF
//  always @(posedge clk) begin
//    if (rst) begin
//      lch_disp_cam <= 1'b0;
//    end else if (lch_disp_cam) begin //Deassert ONLY AT EOF
//      if (!disp_cam_sync && o_rd_frm_done) begin
//        lch_disp_cam <= 1'b0;
//      end
//    end else begin // Assert ANYTIME
//      lch_disp_cam <= disp_cam_sync;
//    end
//  end
 
  // Discard frames if its not top capture frame
  always @(posedge clk) begin
    if (rst) begin
      lch_frm_capt_en <= 1'b0;
    end else begin
      if (frm_capt_sel_sync && capt_en_re) begin
        lch_frm_capt_en <= 1'b1;
      end else if (w_top_frm && wr_eof) begin
        lch_frm_capt_en <= 1'b0;
      end 
    end
  end

  assign send_wr_to_tob = !w_top_frm & lch_frm_capt_en;
  assign capturing_frm = w_top_frm & lch_frm_capt_en;

  // Capture Buffer Discard
  always @(posedge clk) begin
    if (rst) begin
      c_disc_this_buf <= 1'b0;
    end else begin
      if (c_disc_buf_ack) begin
        c_disc_this_buf <= 1'b0;
      end else if (disc_cbuf_re) begin // & c_rbuf_has_frm, Assume there is a frame to read
        c_disc_this_buf <= 1'b1;
      end
    end
  end
  
  // OLED Buffer Discard
  always @(posedge clk) begin
    if (rst) begin
      o_disc_this_buf <= 1'b0;
    end else begin
      if (o_disc_buf_ack) begin
        o_disc_this_buf <= 1'b0;
      end else if (resume_fill_re) begin
        o_disc_this_buf <= 1'b1;
      end
    end
  end
  
  // Freeze Write after capture and before resume
  always @(posedge clk) begin
    if (rst) begin
      wait_for_resume <= 1'b0;
    end else begin
      if (resume_fill_re) begin
        wait_for_resume <= 1'b0;
      end else if (w_tail_frm && wr_eof) begin
        wait_for_resume <= 1'b1;
      end
    end
  end
   
//  reg dbg_mrb_err/* synthesis syn_keep=1 */;
//  // Only for debug
//  always @(posedge clk) begin
//    if (rst) begin
//	  dbg_mrb_err <= 1'b0;
//	end else if (wr_sof && w_sof_maddr[11:0] != 12'b0) begin
//	  dbg_mrb_err <= 1'b1;
//	end
//  end
  
endmodule
`default_nettype wire