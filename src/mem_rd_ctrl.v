`default_nettype none

`include "defines.v"
module mem_rd_ctrl (
  rst,
  clk,
  graphics_mode,
  rpt_rate_ctrl,
  // FCQ
  fcq_wr_addr,
  fcq_wr_en,
  fcq_wdata,
  fcq_rd_en,
  buf_full,
  disc_this_buf,
  disc_buf_ack,
  send_wr_to_tob,
  capturing_frm,
  r_zoom_ctrl,
  r_frm_len,
  // BCQ
  bcq_wr_en,
  bcq_wdata,
  bcq_tob_pulse,
  buf_size,
  // Memory Read Control
  mem_rd_cmd,
  mem_rd_vld,
  rpl_2x_done,
  buf_avail,
  frm_avail,
  r_maddr_d1,
  rd_video_buf,
  rd_frm_buf,
  rd_audio_buf,
  rd_sob,
  rd_eob,
  rd_sof,
  rd_eof,
  rd_end_replay,
  dbg_mrb_err
);
  
  // Parameters
  parameter CAPT_CNTRL_SEL         = 1; //1-Capt 0-OLED
  parameter ADDR_WIDTH             = 25;
  parameter FNUM_WIDTH             = $clog2(`FL_WIDTH);
  
  // Clock & Reset
  input  wire                       rst;
  input  wire                       clk;
  input  wire                       graphics_mode;
  input  wire [4:0]                 rpt_rate_ctrl;
  // FCQ
  input  wire [FNUM_WIDTH-1:0]      fcq_wr_addr;
  input  wire                       fcq_wr_en;
  input  wire [71:0]                fcq_wdata;
  input  wire                       fcq_rd_en;
  input  wire                       buf_full;
  input  wire                       disc_this_buf;
  input  wire                       send_wr_to_tob;
  input  wire                       capturing_frm;
  output wire [3:0]                 r_zoom_ctrl;
  output wire [`FL_WIDTH-1:0]       r_frm_len;
    // BCQ
  input  wire                       bcq_wr_en/* synthesis syn_keep=1 */;
  input  wire [71:0]                bcq_wdata;
  output wire                       bcq_tob_pulse;
  output wire [31:0]                buf_size;
  // Memory Read Control
  input  wire                       mem_rd_cmd;
  input  wire                       mem_rd_vld;
  output reg                        rpl_2x_done;
  output wire                       disc_buf_ack;
  output reg                        buf_avail;
  output reg                        frm_avail;
  output reg  [ADDR_WIDTH-1:0]      r_maddr_d1;
  output reg                        rd_video_buf;
  output reg                        rd_frm_buf;
  output reg                        rd_audio_buf;
  output wire                       rd_sob;
  output wire                       rd_eob;
  output wire                       rd_sof;
  output wire                       rd_eof;
  output wire                       rd_end_replay;
  output reg                        dbg_mrb_err/* synthesis syn_keep=1 */;
  // Local Parameters
  localparam  IDLE                = 14'b00_0000_0000_0001;
  localparam  FCQ_AVAIL           = 14'b00_0000_0000_0010;
  localparam  LOAD_TOP            = 14'b00_0000_0000_0100;
  localparam  LOAD_HEAD           = 14'b00_0000_0000_1000;
  localparam  FRM_RPT_WAIT        = 14'b00_0000_0001_0000;
  localparam  END_OF_BUF          = 14'b00_0000_0010_0000;
  localparam  BCQ_AVAIL           = 14'b00_0000_0100_0000;
  localparam  LOAD_SOF            = 14'b00_0000_1000_0000;
  localparam  LOAD_LIVE           = 14'b00_0001_0000_0000;
  localparam  RD_BCQ              = 14'b00_0010_0000_0000;
  localparam  RD_FCQ              = 14'b00_0100_0000_0000;
  localparam  DISCARD_BUF         = 14'b00_1000_0000_0000;
  localparam  SET_LIVE_MODE       = 14'b01_0000_0000_0000;
  localparam  SET_REPLAY_MODE     = 14'b10_0000_0000_0000;
  
  // Reg and wires
  reg  [13:0]                       c_state;
  reg  [13:0]                       n_state;
  reg  [FNUM_WIDTH-1:0]             r_fnum;
  reg  [FNUM_WIDTH-1:0]             r_fnum_stop;
  wire                              replay_bot_frm;
  wire 			            end_of_playback;
   
  wire [71:0]                       fcq_rdata;
  wire [ADDR_WIDTH-1:0]             r_sof_maddr;
  wire                              r_tail_frm/* synthesis syn_keep=1 */;
  wire                              r_bot_frm;
  wire                              bcq_full;
  wire                              bcq_empty;
  reg                               bcq_empty_d1;
  wire                              bcq_empty_fe;
  reg  [ADDR_WIDTH-1:0]             r_maddr;
  reg  [ADDR_WIDTH-1:0]             rd_word_cntr;
  wire [71:0]                       bcq_rdata;
  wire [FNUM_WIDTH-1:0]             w_top_fnum;
  wire [FNUM_WIDTH-1:0]             r_head_fnum/* synthesis syn_keep=1 */;
  wire [FNUM_WIDTH-1:0]             r_top_fnum/* synthesis syn_keep=1 */;
  wire                              r_replay;
  wire [9:0]                        used_buf_cnt;
  wire [35:0]                       fl_fcq_wdata;
  wire [35:0]                       fl_fcq_rdata;
  wire [71:0]                       bcq_wdata_i;
  reg  [31:0]                       buf_size_cntr;
  wire [`FL_WIDTH-1:0]              w_frm_len;
  wire [`FL_WIDTH-1:0]              prev_r_frm_len;
  wire                              frm_rpt_done;
  reg  [4:0]                        frm_rpt_cntr;
  reg                               buf_rpt_done_i;
  wire                              buf_rpt_done;
  wire                              bcq_rd_req;
  wire                              video_buf_i;
  wire                              frm_buf_i;
  wire                              audio_buf_i;
  wire                              bcq_wr_en_i;
  wire                              is_video_buf;
  wire                              w_tail_frm;
  reg                               in_replay_mode;
  reg                               capturing_frm_d1;
  wire                              capturing_frm_re;
  wire [1:0]                        bcq_full_i;
  wire [1:0]                        bcq_empty_i;
   
  genvar i;

  //================================================
  // FSM
  //================================================
  // Sequential block
  always @(posedge clk) begin
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
        if (!bcq_empty)
          n_state = RD_BCQ;
        else if (graphics_mode && frm_avail)
          n_state = RD_FCQ;
        else
          n_state = IDLE;        

      SET_LIVE_MODE:
        n_state = RD_FCQ;
        
      SET_REPLAY_MODE:
        //if (rd_eof) begin
          n_state = RD_BCQ;
        //end else begin
        //  n_state = SET_REPLAY_MODE;
        //end
        
      RD_BCQ:
        n_state = BCQ_AVAIL;
        
      BCQ_AVAIL:
	n_state = (bcq_empty | in_replay_mode) ? RD_FCQ : RD_BCQ; // if behind, discard
        
      RD_FCQ:
        n_state = FCQ_AVAIL;
        
      FCQ_AVAIL:
        n_state = FRM_RPT_WAIT;
        
      FRM_RPT_WAIT: //Single cycle state
        if (frm_rpt_done) begin
           n_state = (in_replay_mode && !end_of_playback) ? LOAD_TOP : LOAD_LIVE;
        end else begin
           n_state = LOAD_SOF;
        end

      LOAD_TOP:
        if (rd_eof) begin
          n_state = RD_FCQ;
        end else begin
          n_state = LOAD_TOP;
        end
        
      LOAD_HEAD:
        n_state = RD_FCQ;

      LOAD_SOF:
        if (rd_eof) begin
          n_state = RD_FCQ;
        end else begin
          n_state = LOAD_SOF;
        end

      LOAD_LIVE:
        if (rd_eof) begin
	  // If no new frame from camera, re-read current otherwise move to new frame in BCQ
          n_state = bcq_empty ? FCQ_AVAIL : RD_BCQ;
        end else begin
          n_state = LOAD_LIVE;
        end
        
      END_OF_BUF:
        if (disc_this_buf) begin
          n_state = DISCARD_BUF;
        end else begin
          n_state = END_OF_BUF;
        end
        
      DISCARD_BUF:
        if (CAPT_CNTRL_SEL) begin //CAPT- Move out immidiately
          n_state = IDLE;
        end else begin            //OLED- Wait for EOF then move
          if (rd_eof) begin
            n_state = IDLE;
          end else begin
            n_state = DISCARD_BUF;
          end
        end
        
      default: n_state = IDLE;
    endcase
  end
  
  // FCQ read address counter
  always @(posedge clk) begin
    if (rst) begin
      r_fnum <= {FNUM_WIDTH{1'b0}};
    end else if (c_state == SET_LIVE_MODE) begin
      r_fnum <= w_top_fnum;
    end else if (c_state == RD_BCQ) begin
       r_fnum <= r_replay ? r_top_fnum : r_head_fnum;
    end else if (rd_eof) begin
      if (c_state == LOAD_TOP && in_replay_mode)
	  r_fnum <= replay_bot_frm ? 0 : r_fnum + 1;
    end
  end

  assign replay_bot_frm = (r_fnum == (`MAX_FRM_PER_BUF - 1));

  always @(posedge clk)
    if (c_state == RD_BCQ && r_replay)
       r_fnum_stop <= r_head_fnum;

  assign end_of_playback = (r_fnum == r_fnum_stop);
   
  // SOB
  assign rd_sob = ((r_fnum == r_head_fnum) && rd_sof) ? 1'b1 : 1'b0;
  
  // EOB
  assign rd_eob = (r_tail_frm && rd_eof) ? 1'b1 : 1'b0;
  
  // Frame repeat rate control
  always @(posedge clk) begin
    if (rst) begin
      frm_rpt_cntr <= 5'd0;
    end else if (rd_eof) begin
      if (frm_rpt_done) begin
        frm_rpt_cntr <= 5'd0;
      end else begin
        frm_rpt_cntr <= frm_rpt_cntr + 5'd1;
      end
    end
  end
  
  assign frm_rpt_done = (graphics_mode) ? 1'b0 : (!in_replay_mode || frm_rpt_cntr >= rpt_rate_ctrl-1);

  always @(posedge clk)
    if (rst)
      in_replay_mode <= 1'b0;
    else if (c_state == RD_BCQ && r_replay)
      in_replay_mode <= 1'b1;
    else if (end_of_playback) // only if not c_state == RD_BCQ && r_replay
      in_replay_mode <= 1'b0;
  
  assign disc_buf_ack = (c_state == RD_BCQ);
  assign bcq_rd_req = disc_buf_ack ? 1'b1 : 1'b0;
  
  assign is_video_buf = bcq_wdata[20];
  assign w_top_fnum = bcq_wdata[0+:FNUM_WIDTH];
  
  generate
    if (CAPT_CNTRL_SEL) begin : gen_capt
      assign buf_rpt_done = 1'b1;
      // Allow write for all types of buffer, video/audio/frame
      //assign bcq_wr_en_i = bcq_wr_en;
    end else begin : gen_oled
      always @(posedge clk) begin
        if (rst) begin
          buf_rpt_done_i <= 1'b0;
        end else if (rd_eof && (c_state == END_OF_BUF || c_state == LOAD_HEAD)) begin
          buf_rpt_done_i <= ~buf_rpt_done_i;
        end
      end
      assign buf_rpt_done = buf_rpt_done_i;
      
      // Allow write for video, for OLED read
      //assign bcq_wr_en_i = is_video_buf & bcq_wr_en;
    end
  endgenerate

  //assign buf_rpt_done = 1'b1;
  
  // Replay Status
  always @(posedge clk) begin
    if (rst) begin
      rpl_2x_done <= 1'b0;
    end else if (disc_buf_ack) begin
      rpl_2x_done <= 1'b0;
    end else if (buf_rpt_done && r_tail_frm && rd_eof) begin
      rpl_2x_done <= 1'b1;
	end
  end
  
  // Read Buffer Address
  always @(posedge clk) begin
    if (rst) begin
      r_maddr <= {ADDR_WIDTH{1'b0}};
    end else if (c_state == FCQ_AVAIL) begin
      r_maddr <= r_sof_maddr;
    end else if (mem_rd_cmd) begin
      r_maddr <= r_maddr + (`MEM_RD_BL<<2); //c_raddr + BL*4
    end
  end

  // Pipeline for Better Timing, should not affect functionaly
  always @(posedge clk) begin
    r_maddr_d1 <= r_maddr;
  end
  
  // Buffer - trigger read out in arbitrator
  always @(posedge clk) begin
    if (rst || c_state == IDLE) begin
      buf_avail <= 1'b0;
    end else if (c_state == FCQ_AVAIL) begin
      buf_avail <= 1'b1;
    end else if (CAPT_CNTRL_SEL && rd_eof) begin
      buf_avail <= 1'b0;
    end
  end
  
  assign w_tail_frm = fcq_wdata[1+:1];
  
  // Frame - trigger state machine
  always@(posedge clk) begin
    if(rst) begin
      frm_avail <= 1'b0;
    end else if(fcq_wr_en) begin
      if(w_tail_frm) begin
        frm_avail <= 1'b0;
      end else begin
        frm_avail <= 1'b1;
      end
    end
  end
  //================================================
  // Derive Sideband for Read
  //================================================
  always @(posedge clk) begin
    if (rst) begin
      rd_word_cntr <= {`FL_WIDTH{1'b0}};
    end else if(mem_rd_vld) begin
      if (rd_eof) begin
        rd_word_cntr <= {`FL_WIDTH{1'b0}};
      end else begin
        rd_word_cntr <= rd_word_cntr + 'd1;
      end
    end
  end
  
  assign rd_sof = rd_word_cntr == 0 ? 1'b1 : 1'b0;
  assign rd_eof = mem_rd_vld && rd_word_cntr == ((r_frm_len>>2)-1) ? 1'b1 : 1'b0; // (FRAME_LENGTH/4)-1
  assign rd_end_replay = in_replay_mode & end_of_playback;
   
  //================================================
  //** Frame Control Q
  //================================================
  generate
    for (i=0; i<2; i=i+1) begin : fcq_gen  
      sp_bram_36x512 i_fcq (
        .clka                 (clk),
        .reseta               (rst),
        .cea                  (fcq_wr_en),
        .ada                  (fcq_wr_addr),
        .din                  (fcq_wdata[i*36+:36]),
        .clkb                 (clk),
        .resetb               (rst),
        .oce                  (`TIED_TO_VCC),
        .ceb                  (`TIED_TO_VCC),
        .adb                  (r_fnum),
        .dout                 (fcq_rdata[i*36+:36])
      );
    end
  endgenerate
  
  assign r_sof_maddr = fcq_rdata[30+:ADDR_WIDTH];
  assign r_zoom_ctrl = fcq_rdata[26+:4];
  assign r_frm_len   = fcq_rdata[2+:`FL_WIDTH];
  assign r_tail_frm  = fcq_rdata[1+:1];
  assign r_bot_frm   = fcq_rdata[0+:1];
  
  // New Frame length to calculate buffer size
  assign w_frm_len    = fcq_wdata[2+:`FL_WIDTH];
  assign fl_fcq_wdata = {12'b0, w_frm_len};
  sp_bram_36x512 i_fcq_frm_len (
    .clka                 (clk),
    .reseta               (rst),
    .cea                  (fcq_wr_en),
    .ada                  (fcq_wr_addr),
    .din                  (fl_fcq_wdata),
    .clkb                 (clk),
    .resetb               (rst),
    .oce                  (`TIED_TO_VCC),
    .ceb                  (`TIED_TO_VCC),
    .adb                  (fcq_wr_addr),
    .dout                 (fl_fcq_rdata)
  );
  
  // Previously written frame length 
  assign prev_r_frm_len = fl_fcq_rdata[0+:`FL_WIDTH];

  always @(posedge clk) begin
    capturing_frm_d1 <= capturing_frm;
  end

  assign capturing_frm_re = (!capturing_frm_d1) & capturing_frm;
  
  always @(posedge clk) begin
    if (rst || send_wr_to_tob || capturing_frm_re) begin
      buf_size_cntr <= {32{1'b0}};
    end else if (fcq_wr_en) begin
      if (!capturing_frm && buf_full) begin  //Rollover -back to start of the buffer
        buf_size_cntr <= buf_size_cntr + w_frm_len - prev_r_frm_len;
      end else begin
        buf_size_cntr <= buf_size_cntr + w_frm_len;
      end
    end
  end
  //================================================
  //** Buffer Control Q
  //================================================

  //dist_fifo_fwft_32x18 i_bcq (
  //  .Clk                  (clk),
  //  .Reset                (rst),
  //  .WrEn                 (bcq_wr_en),
  //  .Data                 (bcq_wdata),
  //  .Full                 (bcq_full),
  //  .Wnum                 (used_buf_cnt),
  //  .RdEn                 (bcq_tob_pulse),
  //  .Q                    (bcq_rdata),
  //  .Empty                (bcq_empty)
  //);

  //fifo_fwft_18x1024 i_bcq (
  //  .Clk                  (clk),
  //  .Reset                (rst),
  //  .WrEn                 (bcq_wr_en),
  //  .Data                 (bcq_wdata),
  //  .Full                 (bcq_full),
  //  .Wnum                 (used_buf_cnt),
  //  .RdEn                 (1'b0),//bcq_rd_req, bcq_tob_pulse
  //  .Q                    (bcq_rdata),
  //  .Empty                (bcq_empty),
  //  .Almost_Empty         (),
  //  .Almost_Full          ()
  //);
  
  assign bcq_wdata_i[0+:21] = bcq_wdata[0+:21];
  assign bcq_wdata_i[21+:32] = buf_size_cntr;
  assign bcq_wdata_i[53+:19] = 19'b0;
  generate
    for (i=0; i<2; i=i+1) begin : bcq_gen 
      fifo_fwft_36x512 i_bcq (
        .Clk                  (clk),
        .Reset                (rst),
        .WrEn                 (bcq_wr_en),
        .Data                 (bcq_wdata_i[i*36+:36]),
        .Full                 (bcq_full_i[i]),
        .Wnum                 (used_buf_cnt),
        .RdEn                 (bcq_rd_req),//1'b0, bcq_rd_req, bcq_tob_pulse
        .Q                    (bcq_rdata[i*36+:36]),
        .Empty                (bcq_empty_i[i]),
        .Almost_Full          ()
      );
    end
  endgenerate
  
  assign bcq_full    = bcq_full_i[0] & bcq_full_i[1];
  assign bcq_empty   = bcq_empty_i[0] & bcq_empty_i[1];
  
  assign buf_size    = bcq_rdata[21+:32];
  assign r_replay    = bcq_rdata[FNUM_WIDTH+FNUM_WIDTH+2];
  assign frm_buf_i   = bcq_rdata[FNUM_WIDTH+FNUM_WIDTH+1];
  assign audio_buf_i = bcq_rdata[FNUM_WIDTH+FNUM_WIDTH];
  assign r_head_fnum = bcq_rdata[FNUM_WIDTH+FNUM_WIDTH-1:FNUM_WIDTH];
  assign r_top_fnum  = bcq_rdata[FNUM_WIDTH-1:0];
  
  always @(posedge clk) begin
    bcq_empty_d1 <= bcq_empty;
  end
  
  assign bcq_empty_fe = (!bcq_empty) & bcq_empty_d1;

  // Register for breaking timing path
  always @(posedge clk) begin
    rd_video_buf <= video_buf_i;
    rd_frm_buf   <= frm_buf_i;
    rd_audio_buf <= audio_buf_i;
  end
  
  always @(posedge clk) begin
    if (rst) begin
	  dbg_mrb_err <= 1'b0;
	end else if (rd_sof && mem_rd_cmd && r_maddr_d1 != 12'b0) begin
	  dbg_mrb_err <= 1'b1;
	end
  end
endmodule
`default_nettype wire