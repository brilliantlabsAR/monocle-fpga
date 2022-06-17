`default_nettype none

`include "defines.v"
`include "reg_addr_defines.v"

module reg_if (
  clk,
  rst_n,
  wr_addr,
  wr_en,
  wr_data,
  rd_addr,
  rd_en,
  rd_data,
  rst_sw,
  led_control,
  mem_init_done,
  dbg_mrb_err,
  err_wr_vbfifo_full,
  err_rd_vbfifo_full, //TBD
  err_abfifo_full,
  disp_fifo_underrun,
  disp_fifo_overrun,  //TBD
  capt_fifo_underrun,
  capt_fifo_overrun, 
  `ifdef EN_DEBUG_CNTR
  //Only for debug
  cam_frm_per_sec,
  cam_total_frm,
  cam_total_byte,
  cam_lines_per_frm,
  cam_bytes_per_line,
  cam_bytes_per_frm,
  cam_frm_lt_512k_err,
  disp_frm_per_sec,
  disp_total_frm,
  disp_total_byte,
  disp_lines_per_frm,
  disp_bytes_per_line,
  disp_bytes_per_frm,
  disp_frm_lt_512k_err,
  `endif
  en_xclk,
  en_cam,
  en_zoom,
  en_luma_cor,
  sel_zoom_mode,
  en_mic,
  sync_to_video,
  en_rb_shift,
  disp_bars,
  disp_busy,
  disp_cam,
  mem_control,
  discard_cbuf,
  clr_chksm,
  resume_fill,
  rd_audio,
  capt_audio,
  capt_video,
  capt_frm,
  capt_en,
  rep_rate_control,
  wr_burst_size,
  rd_burst_size,
  burst_wr_en,
  burst_wdata,
  o_rpl_2x_done,
  c_frm_len,
  c_sel_zoom_mode,
  c_en_zoom,
  c_en_luma_cor,
  video_buf,
  frm_buf,
  audio_buf,
  c_buf_size,
  sob,
  eob,
  cfifo_rd_vld,
  burst_rd_en,
  burst_rdata,
  capt_byte_cntr,
  capt_frm_chk_sum
);

  //IOs
  input  wire                        clk;
  input  wire                        rst_n;
                                     
  input  wire [`REG_ADDR_WIDTH-1:0]  wr_addr;
  input  wire                        wr_en;
  input  wire [`REG_SIZE-1:0]        wr_data;
  input  wire [`REG_ADDR_WIDTH-1:0]  rd_addr;
  input  wire                        rd_en;
  output reg  [`REG_SIZE-1:0]        rd_data;
  output reg                         rst_sw;
  output reg  [`REG_SIZE-1:0]        led_control;
  input  wire                        mem_init_done;
  input  wire                        dbg_mrb_err;
  input  wire                        err_wr_vbfifo_full;
  input  wire                        err_rd_vbfifo_full;
  input  wire                        err_abfifo_full;
  input  wire                        disp_fifo_overrun;
  input  wire                        disp_fifo_underrun;
  input  wire                        capt_fifo_underrun;
  input  wire                        capt_fifo_overrun;
  
  `ifdef EN_DEBUG_CNTR
  input  wire [7:0]                  cam_frm_per_sec;
  input  wire [`STAT_CNTR_WIDTH-1:0] cam_total_frm;
  input  wire [`STAT_CNTR_WIDTH-1:0] cam_total_byte;
  input  wire [10:0]                 cam_lines_per_frm;
  input  wire [11:0]                 cam_bytes_per_line;
  input  wire [18:0]                 cam_bytes_per_frm;
  input  wire                        cam_frm_lt_512k_err;
         
  input  wire [7:0]                  disp_frm_per_sec;
  input  wire [`STAT_CNTR_WIDTH-1:0] disp_total_frm;
  input  wire [`STAT_CNTR_WIDTH-1:0] disp_total_byte;
  input  wire [10:0]                 disp_lines_per_frm;
  input  wire [11:0]                 disp_bytes_per_line;
  input  wire [18:0]                 disp_bytes_per_frm;
  input  wire                        disp_frm_lt_512k_err;
  `endif
  output reg                         en_xclk;
  output reg                         en_cam;
  output reg                         en_zoom;
  output reg                         en_luma_cor;
  output reg  [1:0]                  sel_zoom_mode;
  
  output reg                         en_mic;
  output reg                         sync_to_video;
  
  output reg                         en_rb_shift;
  output reg                         disp_bars;
  output reg                         disp_busy;
  output reg                         disp_cam;
  
  output reg  [`REG_SIZE-1:0]        mem_control;
  output reg                         discard_cbuf;
  output reg                         clr_chksm;
  output reg                         resume_fill;
  output reg                         rd_audio;
  output reg                         capt_audio;
  output reg                         capt_video;
  output reg                         capt_frm;
  output reg                         capt_en;
  output reg  [4:0]                  rep_rate_control;
  output reg  [`BURST_WIDTH-1:0]     wr_burst_size;
  output reg  [`BURST_WIDTH-1:0]     rd_burst_size;
  output reg                         burst_wr_en;
  output reg  [`REG_SIZE-1:0]        burst_wdata;
  input  wire                        o_rpl_2x_done;
  input  wire [31:0]                 c_buf_size;
  input  wire [23:0]                 c_frm_len;
  input  wire [1:0]                  c_sel_zoom_mode;
  input  wire                        c_en_zoom;
  input  wire                        c_en_luma_cor;
  input  wire                        video_buf;
  input  wire                        frm_buf;
  input  wire                        audio_buf;
  input  wire                        sob;
  input  wire                        eob;
  input  wire                        cfifo_rd_vld;
  output wire                        burst_rd_en;
  input  wire [`REG_SIZE-1:0]        burst_rdata;
  input  wire [31:0]                 capt_byte_cntr;
  input  wire [15:0]                 capt_frm_chk_sum;
  
  reg                                dbg_cam_stat_sel;
  wire                               frm_len_err;
  wire                               err_int/* synthesis syn_keep=1 */;
  
  reg                                wr_error_d1;
  reg                                err_wr_vbfifo_full_d1;
  reg                                err_rd_vbfifo_full_d1;
  reg                                err_abfifo_full_d1;
  reg                                disp_fifo_underrun_d1;
  reg                                disp_fifo_overrun_d1;
  reg                                capt_fifo_underrun_d1;
  reg                                capt_fifo_overrun_d1;
                                     
  reg                                wr_error_d2;
  reg                                err_wr_vbfifo_full_d2;
  reg                                err_rd_vbfifo_full_d2;
  reg                                err_abfifo_full_d2;
  reg                                disp_fifo_underrun_d2;
  reg                                disp_fifo_overrun_d2;
  reg                                capt_fifo_underrun_d2;
  reg                                capt_fifo_overrun_d2;  
  
  // Write Control
  always @(posedge clk) begin
    // Default value
    burst_wr_en        <= 1'b0;
    if (!rst_n) begin
      rst_sw           <= 1'b0;
      en_cam           <= 1'b0;
      en_zoom          <= 1'b0;
      en_luma_cor      <= 1'b0;
      sel_zoom_mode    <= 2'b00;
      en_rb_shift      <= 1'b0;
      disp_bars        <= 1'b0;
      disp_busy        <= 1'b0;
      disp_cam         <= 1'b1;
      mem_control      <= 8'h02;
      led_control      <= 8'h00;
      en_xclk          <= 1'b0;
      sync_to_video    <= 1'b0;
      en_mic           <= 1'b0;
      discard_cbuf     <= 1'b0;
      clr_chksm        <= 1'b0;
      resume_fill      <= 1'b0;
      rd_audio         <= 1'b0;
      capt_audio       <= 1'b0;
      capt_video       <= 1'b0;
      capt_frm         <= 1'b0;
      capt_en          <= 1'b0;
      rep_rate_control <= 5'h3;
      wr_burst_size    <= 16'h1;
      rd_burst_size    <= 16'h1;
      burst_wr_en      <= 1'b0;
      burst_wdata      <= 8'h0;
      dbg_cam_stat_sel <= 1'b0;
    end else if (wr_en) begin
      case (wr_addr)
        `SYSTEM_CONTROL: begin
          rst_sw <= wr_data[0];
        end
        
        `DISPLAY_CONTROL: begin
          en_rb_shift <= wr_data[3];
          disp_bars   <= wr_data[2];
          disp_busy   <= wr_data[1];
          disp_cam    <= wr_data[0];
        end
        
        `MEMORY_CONTROL: begin
          mem_control <= wr_data;
        end
        
        `LED_CONTROL: begin
          led_control <= wr_data;
        end
        
        `CAMERA_CONTROL: begin
          en_luma_cor      <= wr_data[5];
          en_zoom          <= wr_data[4];
          sel_zoom_mode    <= wr_data[3:2];
          en_cam           <= wr_data[1];
          en_xclk          <= wr_data[0];
        end
        
        `MIC_CONTROL: begin
          sync_to_video <= wr_data[1];
          en_mic        <= wr_data[0];
        end
        
        `WR_BURST_SIZE_LOW: begin
          wr_burst_size[7:0] <= wr_data;
        end
        
        `WR_BURST_SIZE_HIGH: begin
          wr_burst_size[15:8] <= wr_data;
        end
        
        `RD_BURST_SIZE_LOW: begin
          rd_burst_size[7:0] <= wr_data;
        end
        
        `RD_BURST_SIZE_HIGH: begin
          rd_burst_size[15:8] <= wr_data;
        end
        
        `BURST_WR_DATA: begin
          burst_wr_en <= 1'b1;
          burst_wdata <= wr_data;
        end
        
        `CAPTURE_CONTROL: begin
	      discard_cbuf <= wr_data[7];
	      clr_chksm    <= wr_data[6];
	      resume_fill  <= wr_data[5];
	      rd_audio     <= wr_data[4];
	      capt_audio   <= wr_data[3];
	      capt_video   <= wr_data[2];
	      capt_frm     <= wr_data[1];
	      capt_en      <= wr_data[0];
        end
        
        `REPLAY_RATE_CONTROL: begin
          rep_rate_control <= wr_data[4:0];
        end
        
        `ifdef EN_DEBUG_CNTR
        //Only for Debug
        `DEBUG_CONTROL: begin
          dbg_cam_stat_sel <= wr_data[0];
        end
        `endif
        
      endcase
    end
  end
  
  `ifdef EN_DEBUG_CNTR
    assign frm_len_err = dbg_cam_stat_sel ? cam_frm_lt_512k_err : disp_frm_lt_512k_err;
  `endif
  
  // Read Control
  //always @(posedge clk) begin
  always @(*) begin
    case (rd_addr)
      
      `SYSTEM_CONTROL: begin
        rd_data <= {7'h0, rst_sw};
      end
      
      `SYSTEM_STATUS: begin
        rd_data[7] <= err_abfifo_full;
        rd_data[6] <= capt_fifo_underrun;
        rd_data[5] <= capt_fifo_overrun;
        rd_data[4] <= disp_fifo_underrun;
        rd_data[3] <= err_wr_vbfifo_full;
        rd_data[2] <= err_int;
        rd_data[1] <= 1'b0;//wr_error
        rd_data[0] <= mem_init_done;
      end

      `DISPLAY_CONTROL: begin
        rd_data[7:4] <= 4'h0;
        rd_data[3]   <= en_rb_shift;
        rd_data[2]   <= disp_bars;
        rd_data[1]   <= disp_busy;
        rd_data[0]   <= disp_cam;
      end
      
      `MEMORY_CONTROL: begin
        rd_data <= mem_control;
      end
      
      `LED_CONTROL: begin
        rd_data <= led_control;
      end
      
      `CAMERA_CONTROL: begin
        rd_data[7:6] <= 2'h0;
        rd_data[5]   <= en_luma_cor;
        rd_data[4]   <= en_zoom;
        rd_data[3:2] <= sel_zoom_mode;
        rd_data[1]   <= en_cam;
        rd_data[0]   <= en_xclk;
      end

        
      `MIC_CONTROL: begin
        rd_data[7:2] <= 6'h0;
        rd_data[1]   <= sync_to_video;
        rd_data[0]   <= en_mic;
      end
        
      `WR_BURST_SIZE_LOW: begin
        rd_data <= wr_burst_size[7:0];
      end

      `WR_BURST_SIZE_HIGH: begin
        rd_data <= wr_burst_size[15:8];
      end

      `BURST_WR_DATA: begin
        rd_data <= burst_wdata;
      end

      `RD_BURST_SIZE_LOW: begin
        rd_data <= rd_burst_size[7:0];
      end

      `RD_BURST_SIZE_HIGH: begin
        rd_data <= rd_burst_size[15:8];
      end

      `BURST_RD_DATA: begin
        rd_data <= burst_rdata;
      end
      
      `CAPTURE_CONTROL: begin
	    rd_data[7]   <= discard_cbuf;
	    rd_data[6]   <= clr_chksm;
	    rd_data[5]   <= resume_fill;
	    rd_data[4]   <= rd_audio;
	    rd_data[3]   <= capt_audio;
	    rd_data[2]   <= capt_video;
	    rd_data[1]   <= capt_frm;
	    rd_data[0]   <= capt_en;
      end

      `CAPTURE_STATUS: begin
        rd_data[7:6] <= 3'h0;
        rd_data[5]   <= video_buf;
        rd_data[4]   <= frm_buf;
        rd_data[3]   <= audio_buf;
        rd_data[2]   <= eob;
        rd_data[1]   <= sob;
        rd_data[0]   <= cfifo_rd_vld; //capt_rd_vld 
      end
      
      `CAPTURE_SIZE_0: begin
        rd_data <= c_buf_size[7:0];
      end
      `CAPTURE_SIZE_1: begin
        rd_data <= c_buf_size[15:8];
      end
      `CAPTURE_SIZE_2: begin
        rd_data <= c_buf_size[23:16];
      end
      `CAPTURE_SIZE_3: begin
        rd_data <= c_buf_size[31:24];
      end
      
      `CAPT_FRM_CHECKSUM_0: begin
        rd_data <= capt_frm_chk_sum[7:0];
      end

      `CAPT_FRM_CHECKSUM_1: begin
        rd_data <= capt_frm_chk_sum[15:8];
      end
      
      `CAPT_BYTE_COUNT_0: begin
        rd_data <= capt_byte_cntr[7:0];
      end

      `CAPT_BYTE_COUNT_1: begin
        rd_data <= capt_byte_cntr[15:8];
      end
      
      `CAPT_BYTE_COUNT_2: begin
        rd_data <= capt_byte_cntr[23:16];
      end
      
      `CAPT_BYTE_COUNT_3: begin
        rd_data <= capt_byte_cntr[31:24];
      end

      `CAPTURE_FRM_LEN_BYTE0: begin
        rd_data <= c_frm_len[7:0];
      end
      
      `CAPTURE_FRM_LEN_BYTE1: begin
        rd_data <= c_frm_len[15:8];
      end
      
      `CAPTURE_FRM_LEN_BYTE2: begin
        rd_data <= c_frm_len[23:16];
      end
      
      `CAPTURE_FRM_SIDEBAND: begin
        rd_data <= {4'b0, c_en_luma_cor, c_en_zoom, c_sel_zoom_mode};
      end      
      
      `FPGA_VERSION_MINOR: begin
        rd_data <= `REVISION_MINOR;
      end

      `FPGA_VERSION_MAJOR: begin
        rd_data <= `REVISION_MAJOR;
      end
      
      `REPLAY_RATE_CONTROL: begin
        rd_data[7:5] <= 0;
        rd_data[4:0] <= rep_rate_control[4:0];
      end
        
      `ifdef EN_DEBUG_CNTR
      //Only for Debug
      `DEBUG_CONTROL: begin
        rd_data <= {6'h0, frm_len_err, dbg_cam_stat_sel};
      end
      
      `DBG_FRM_PER_SEC: begin
        rd_data <= dbg_cam_stat_sel ? cam_frm_per_sec : disp_frm_per_sec;
      end
      
      `DBG_TOTAL_FRM0: begin
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[7:0] : disp_total_frm[7:0];
      end
      `DBG_TOTAL_FRM1: begin
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[15:8] : disp_total_frm[15:8];
      end
      `DBG_TOTAL_FRM2: begin
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[23:16] : disp_total_frm[23:16];
      end                                                               
      `DBG_TOTAL_FRM3: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[31:24] : disp_total_frm[31:24];
      end                                                               
      `DBG_TOTAL_FRM4: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[39:32] : disp_total_frm[39:32];
      end                                                               
      `DBG_TOTAL_FRM5: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[47:40] : disp_total_frm[47:40];
      end                                                               
      `DBG_TOTAL_FRM6: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[55:48] : disp_total_frm[55:48];
      end                                                               
      `DBG_TOTAL_FRM7: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_frm[63:56] : disp_total_frm[63:56];
      end
      
      `DBG_TOTAL_BYTE0: begin
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[7:0] : disp_total_byte[7:0];
      end
      `DBG_TOTAL_BYTE1: begin
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[15:8] : disp_total_byte[15:8];
      end
      `DBG_TOTAL_BYTE2: begin
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[23:16] : disp_total_byte[23:16];
      end                                                               
      `DBG_TOTAL_BYTE3: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[31:24] : disp_total_byte[31:24];
      end                                                               
      `DBG_TOTAL_BYTE4: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[39:32] : disp_total_byte[39:32];
      end                                                               
      `DBG_TOTAL_BYTE5: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[47:40] : disp_total_byte[47:40];
      end                                                               
      `DBG_TOTAL_BYTE6: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[55:48] : disp_total_byte[55:48];
      end                                                               
      `DBG_TOTAL_BYTE7: begin                                            
        rd_data <= dbg_cam_stat_sel ? cam_total_byte[63:56] : disp_total_byte[63:56];
      end
      
      `DBG_LINE_PER_FRM0: begin
        rd_data <= dbg_cam_stat_sel ? cam_lines_per_frm[7:0] : disp_lines_per_frm[7:0];
      end
      `DBG_LINE_PER_FRM1: begin
        rd_data <= dbg_cam_stat_sel ? {5'b0, cam_lines_per_frm[10:8]} : {5'b0, disp_lines_per_frm[10:8]};
      end
      
      `DBG_BYTE_PER_LINE0: begin
        rd_data <= dbg_cam_stat_sel ? cam_bytes_per_line[7:0] : disp_bytes_per_line[7:0];
      end
      `DBG_BYTE_PER_LINE1: begin
        rd_data <= dbg_cam_stat_sel ? {4'b0, cam_bytes_per_line[11:8]} : {4'b0, disp_bytes_per_line[11:8]};
      end

      `DBG_BYTE_PER_FRM0: begin
        rd_data <= dbg_cam_stat_sel ? cam_bytes_per_frm[7:0] : disp_bytes_per_frm[7:0];
      end
      `DBG_BYTE_PER_FRM1: begin
        rd_data <= dbg_cam_stat_sel ? cam_bytes_per_frm[15:8] : disp_bytes_per_frm[15:8];
      end
      `DBG_BYTE_PER_FRM2: begin
        rd_data <= dbg_cam_stat_sel ? {5'b0, cam_bytes_per_frm[18:16]} : {5'b0, disp_bytes_per_frm[18:16]};
      end
      `endif
      
      default : rd_data = 8'h00;
    endcase
  end
  
  // Synchronize signals from different domains to avoid timing errors  
  always@(posedge clk) begin
    err_wr_vbfifo_full_d1 <= err_wr_vbfifo_full;
    err_rd_vbfifo_full_d1 <= err_rd_vbfifo_full;
    err_abfifo_full_d1    <= err_abfifo_full;
    disp_fifo_underrun_d1 <= disp_fifo_underrun;
    disp_fifo_overrun_d1  <= disp_fifo_overrun;
    capt_fifo_underrun_d1 <= capt_fifo_underrun;
    capt_fifo_overrun_d1  <= capt_fifo_overrun;
    
    err_wr_vbfifo_full_d2 <= err_wr_vbfifo_full_d1;
    err_rd_vbfifo_full_d2 <= err_rd_vbfifo_full_d1;
    err_abfifo_full_d2    <= err_abfifo_full_d1;
    disp_fifo_underrun_d2 <= disp_fifo_underrun_d1;
    disp_fifo_overrun_d2  <= disp_fifo_overrun_d1;
    capt_fifo_underrun_d2 <= capt_fifo_underrun_d1;
    capt_fifo_overrun_d2  <= capt_fifo_overrun_d1;
  end
  
  
  assign err_int = //wr_error_d2           || //arbiter memory full error
                   //rd_error_d2           || //arbiter memory empty error ///UNUSED
                   dbg_mrb_err || //video burst buffer full error
                   err_wr_vbfifo_full_d2 || //video burst buffer full error
                   err_rd_vbfifo_full_d2 || //read video burst buffer full error
                   err_abfifo_full_d2    || //audio burst buffer full error
                   disp_fifo_underrun_d2 || //display fifo underrun
                   disp_fifo_overrun_d2  || //display fifo overrun
                   capt_fifo_underrun_d2 || //capture fifo underrun
                   capt_fifo_overrun_d2;    //capture fifo overrun
                   
  assign burst_rd_en = (rd_addr == `BURST_RD_DATA) & rd_en ? 1'b1 : 1'b0;
  
endmodule

`default_nettype wire