`default_nettype none
`timescale 1ps/1ps
`include "defines.v"

`include "apsram_local_define.v"
`include "apsram_define.v"


module fpga_top (
`ifdef MK11
`else
  clk_24mhz,
`endif
  // SPI Slave Interface
  SCLK,
  MOSI,
  MISO,
  SS,
  // Mic Interface
  mic_clk,
  mic_data,
`ifdef MK11
  mic_ws,
`endif
  // Camera Interface
  cam_clk,
  cam_xclk,
  cam_href,
  cam_vsync,
  cam_data,
  // Memory Interface
  mem_clk,
  mem_ce_n,
  mem_dqs_mask,
  mem_dq,
  // Display Interface
  disp_mclk,
  disp_hsync,
  disp_vsync,
  disp_data
);


`include "apsram_param.v"
`include "apsram_local_param.v"

  // Parameters
  
  //parameter CLKFREQ               = 27000000; //27Mhz
  //parameter CNTR_WIDTH            = $clog2(CLKFREQ);
  
  //IOs
`ifdef MK11
`else
  input  wire                       clk_24mhz;
`endif
  // SPI Slave Interface
  input  wire                       SCLK;
  input  wire                       MOSI;
  output wire                       MISO;
  input  wire                       SS;
  // Mic Interface
  output wire                       mic_clk;
  input  wire                       mic_data;
`ifdef MK11
  output wire                       mic_ws;
`endif
  // Camera Interface
  input  wire                       cam_clk;
  output wire                       cam_xclk;
  input  wire                       cam_href;
  input  wire                       cam_vsync;
  input  wire [`CAM_DSIZE-1:0]      cam_data;
  // Memory Interface
  output wire [CS_WIDTH-1:0]        mem_clk;
  inout  wire [CS_WIDTH-1:0]        mem_dqs_mask;
  inout  wire [DQ_WIDTH-1:0]        mem_dq;
  output wire [CS_WIDTH-1:0]        mem_ce_n;
  // Display Interface
  output wire                       disp_mclk;
  output wire                       disp_hsync;
  output wire                       disp_vsync;
  output wire [`DISP_DSIZE-1:0]     disp_data;


  reg  [31:0]                       rst_shift_reg; 
  wire                              rst_hw; 
  wire                              rst_sw; 
  wire                              mem_async_rst_n; 
  wire                              async_rst; 
  wire                              async_rst_n; 
  wire                              sys_rst; 
  wire                              reg_rst; 
  wire                              cam_rst; 
  wire                              disp_rst; 
  wire                              sys_clk;
  wire                              clk_27mhz;
  wire                              clk_27mhz_180;
  wire                              disp_pll_lock; 
  wire                              clk_80mhz;
  wire                              mem_pll_lock;
  
  
  wire [`REG_ADDR_WIDTH-1:0]        wr_addr;
  wire                              wr_en;
  wire [`REG_SIZE-1:0]              wr_data;
  wire [`REG_ADDR_WIDTH-1:0]        rd_addr;
  wire                              rd_en;
  wire [`REG_SIZE-1:0]              rd_data;
  
  wire                              en_xclk;
  wire                              en_cam;
  wire                              en_playback;
  wire                              en_zoom;
  wire                              en_luma_cor;
  wire [1:0]                        sel_zoom_mode;
   wire 			    replay_toggle;
   
  wire 			            en_graphics, graphics_swap_toggle;
  wire 			            graphics_base_wren;
  wire [31:0] 			    graphics_base_val;
  wire [31:0] 			    gr_wr_base;
  wire 			            gr_wr_base_rd;
  wire 			            gr_wr_base_vld;

  wire                              en_mic;
  wire                              sync_to_video;
  
  wire [7:0]                        led_control;
  
  wire [`CAM_DSIZE-1:0]             bar_data;
  wire                              bar_href;
  wire                              bar_hs;
  wire                              bar_vs;
  reg                               rst_sw_d1;
  wire                              rst_sw_pulse;
  
  wire                              cam_vld;
  wire [`CAM_DSIZE-1:0]             cam_rd_data;
  wire                              cam_sof;
  wire                              cam_eof;
  wire                              ctrl_wr_en;
  wire [35:0]                       ctrl_wr_data;
  
  wire                              comp_vld;
  wire                              comp_rdy;
  wire [31:0]                       comp_data;
  wire [1:0]                        comp_be;
  wire                              comp_sof;
  wire                              comp_eof;
  
  wire [`DSIZE-1:0]                 comp_data_i;
  
  wire                              v_burst_avail;
  wire                              v_rd_en;
  wire [`DSIZE-1:0]                 v_rd_data;
  wire                              err_wr_vbfifo_full;
  
  wire                              slow_sys_clk;
  wire                              pcm_valid;
  wire [`PCM_DSIZE-1:0]             pcm_data;
  
  wire                              a_burst_avail;
  wire                              a_rd_en;
  wire [`DSIZE-1:0]                 a_rd_data;
  wire                              err_abfifo_full;

  wire 			    gr_wr_en;
  wire [15:0] 		    gr_wr_data; 
  wire 			    gr_burst_avail;
  wire 			    gr_rd_en;
  wire [`DSIZE-1:0] 	    gr_rd_data;

  wire 			    o_buf_avail;
  wire 			    c_buf_avail;
  wire 			    o_frm_avail;
  wire 			    c_frm_avail;
  
  wire [7:0]                        cam_frm_per_sec;
  wire [`STAT_CNTR_WIDTH-1:0]       cam_total_frm;
  wire [`STAT_CNTR_WIDTH-1:0]       cam_total_byte;
  wire [10:0]                       cam_lines_per_frm;
  wire [11:0]                       cam_bytes_per_line;
  wire [18:0]                       cam_bytes_per_frm;
  wire                              cam_frm_lt_512k_err;
  
  wire                              discard_cbuf;
  wire                              clr_chksm;
  wire                              resume_fill;
  wire                              rd_audio;
  wire                              capt_audio;
  wire                              capt_video;
  wire                              capt_frm;
  wire                              capt_en;
  wire [4:0]                        rep_rate_control;
  wire [31:0]                       c_buf_size;
  
  wire                              rd_bfifo_afull;
  wire                              rd_bfifo_wr_en;
  wire [`DSIZE-1:0]                 rd_bfifo_wr_data;
  wire                              rd_ctrl_req;
  wire [35:0]                       rd_ctrl_data;
  wire [35:0]                       trim_zoom_ctrl;
  
  wire                              cfifo_afull;
  wire                              cfifo_wr_en;
  wire [`DSIZE-1:0]                 cfifo_wr_data;
  
  wire                              mem_init_done;
  wire [ADDR_WIDTH-1:0]             mem_addr;
  wire                              mem_cmd;
  wire                              mem_cmd_en;
  wire [4*DQ_WIDTH-1:0]             mem_wr_data;
  wire                              mem_wr_en;
  wire                              mem_cmd_rdy;
  wire [4*DQ_WIDTH-1:0]             mem_rd_data;
  wire                              mem_rd_data_valid;
  wire [CS_WIDTH*MASK_WIDTH-1:0]    mem_data_mask;
  wire [9:0]                        mem_burst_num;
  
  wire                              trim_rdy;
  wire                              rd_burst_vld;
  wire [`DSIZE-1:0]                 rd_burst_data;
  wire                              err_rd_vbfifo_full;
  
  wire                              trim_sof;
  wire                              trim_eof;
  wire [`FL_WIDTH-1:0]              trim_frm_len;
  wire                              trim_vld;

  wire                              zoom_vld;
  wire                              zoom_rdy;
  wire [`DSIZE-1:0]                 zoom_data;

  wire                              luma_vld;
  wire                              luma_rdy;
  wire [`DSIZE-1:0]                 luma_data;
  
  wire                              luma_vld_d1;
  wire                              luma_rdy_d1;
  wire [`DSIZE-1:0]                 luma_data_d1;

  wire                              en_rb_shift;
  wire                              rb_vld;
  wire                              rb_rdy;
  wire [`DSIZE-1:0]                 rb_data;
  
  wire                              rb_vld_d1;
  wire                              rb_rdy_d1;
  wire [`DSIZE-1:0]                 rb_data_d1;

  wire                              disp_rdy;
  wire                              disp_rdy_d1;
  wire                              disp_fifo_overrun;
  wire                              disp_fifo_underrun;
  wire                              disp_bars;
  wire                              disp_busy;
  wire                              disp_cam;
  
  wire [7:0]                        disp_frm_per_sec;
  wire [`STAT_CNTR_WIDTH-1:0]       disp_total_frm;
  wire [`STAT_CNTR_WIDTH-1:0]       disp_total_byte;
  wire [10:0]                       disp_lines_per_frm;
  wire [11:0]                       disp_bytes_per_line;
  wire [18:0]                       disp_bytes_per_frm;
  wire                              disp_frm_lt_512k_err;
  
    
  wire                              sob;
  wire                              eob;
  wire                              cfifo_rd_vld;
  wire                              cfifo_rd_en;
  wire [11:0] 			    cfifo_rd_cnt;
  wire [`REG_SIZE-1:0]              cfifo_rd_data;
  wire                              video_buf;
  wire                              audio_buf;
  wire [31:0]                       capt_byte_cntr;
  wire [15:0]                       capt_frm_chk_sum;
  wire                              capt_fifo_underrun;
  wire                              capt_fifo_overrun;
  wire                              disp_href;
  wire [23:0]                       c_frm_len;
  wire [1:0]                        c_sel_zoom_mode;
  wire                              c_en_zoom;
  wire                              c_en_luma_cor;
  wire                              c_rd_video_buf;
  wire                              c_rd_frm_buf;
  wire                              c_rd_audio_buf;
  wire                              disp_avail;
  wire                              clk_board;
  wire                              o_rpl_2x_done;
  wire                              dbg_mrb_err;
    
  `ifdef MK11
  onchip_osc i_onchip_osc (
    .oscout(clk_board)
  );
  `else
  assign clk_board = clk_24mhz;
  `endif
  
  //================================================
  // Power-On Reset
  //================================================
  // For Simulation Only
  initial begin
    `ifdef MK11
    rst_shift_reg = 32'hFFFFFFFF;
    `else
    rst_shift_reg = 32'h000000FF;
    `endif
  end
  
  always @(posedge clk_board) begin 
    rst_shift_reg <= {1'b0,rst_shift_reg[31:1]};
  end 
  
  assign rst_hw = rst_shift_reg[0] | ~(disp_pll_lock & mem_pll_lock);

  // Software Reset
  always @(posedge clk_board) begin 
    rst_sw_d1 <= rst_sw;
  end
  
  assign rst_sw_pulse = rst_sw & (!rst_sw_d1);
  
  // Final Combined Reset  
  assign async_rst   = rst_sw_pulse | rst_hw | (!mem_init_done);
  assign mem_async_rst_n   = ~(rst_sw_pulse | rst_hw);
  //assign async_rst_n = ~async_rst;
  
  // Not resetting memory controller because it stops clock for sometime after reset which make FIFO behavious different.
  assign async_rst_n = ~rst_hw; //Not resetting 

  
  rst_sync i_rst_sync (
    .sys_clk              (sys_clk),
    .reg_clk              (clk_board),
    .cam_clk              (cam_clk),
    .disp_clk             (clk_27mhz),
    .rst                  (async_rst),
    .sys_rst              (sys_rst),
    .reg_rst              (reg_rst),
    .cam_rst              (cam_rst),
    .disp_rst             (disp_rst)
  );
  
  //================================================
  // Clock Generation
  //================================================
  // Display Clock Generation
  disp_pll i_disp_pll (
    .clkin                (clk_board),
    .lock                 (disp_pll_lock),
    .clkout               (clk_27mhz),
    .clkoutp              (clk_27mhz_180)
  );
 
  // Memory Clock Generation
  mem_pll i_mem_pll (
    .clkin                (clk_board),
    .lock                 (mem_pll_lock),
    .clkout               (clk_80mhz)
  );
  
  `ifdef DISABLE_CAMERA
  color_bar i_color_bar (
    .clk                  (cam_clk),
    .rst                  (async_rst),
    .en_cam               (1'b1),
    .hs                   (bar_hs),
    .vs                   (bar_vs),
    .de                   (bar_href),
    .data                 (bar_data)
  );
  `endif
  
  //================================================
  // Camera Interface
  //================================================
  cam_if i_cam_if (
    .cam_rst              (async_rst),
    .clk_board            (clk_board),
    .cam_clk              (cam_clk),
    .cam_xclk             (cam_xclk),
    `ifdef DISABLE_CAMERA
    .cam_data             (bar_data),
    .cam_href             (bar_href),
    .cam_vsync            (bar_vs),
    `else
    .cam_data             (cam_data),
    .cam_href             (cam_href),
    .cam_vsync            (cam_vsync),
    `endif
    .en_xclk              (en_xclk),
    .en_cam               (en_cam),
    //.high_res_mode_en     (1'b0),//capt_frm
    .cam_vld              (cam_vld),
    .cam_rd_data          (cam_rd_data),
    .cam_sof              (cam_sof),
    .cam_eof              (cam_eof)
  );
  
  //================================================
  // Compression
  //================================================
  dc_8to32 i_compress (
    .clk                  (cam_clk),
    .rst                  (cam_rst),
    .s_vld_i              (cam_vld),
    .s_rdy_o              (),
    .s_data_i             (cam_rd_data),
    .s_sof_i              (cam_sof),
    .s_eof_i              (cam_eof),
    .m_vld_o              (comp_vld),
    .m_rdy_i              (comp_rdy),
    .m_data_o             (comp_data),
    .m_be_o               (comp_be),
    .m_sof_o              (comp_sof),
    .m_eof_o              (comp_eof)
  );
  
  assign comp_data_i = {comp_be, comp_eof, comp_sof, comp_data};
  
  wr_burst_afifo i_wr_burst_afifo (
    .wr_rst               (cam_rst),
    .wr_clk               (cam_clk),
    .wr_vld_i             (comp_vld),
    .wr_rdy_o             (comp_rdy),
    .wr_data_i            (comp_data_i),
    .rd_rst               (sys_rst),
    .rd_clk               (sys_clk),
    .burst_avail          (v_burst_avail),
    .burst_rd_en          (v_rd_en),
    .burst_rd_data        (v_rd_data),
    .err_bfifo_full       (err_wr_vbfifo_full)
  );
  
  // Mic Interface
  `ifdef EN_MIC_IF
  mic_if i_mic_if (
    .clk_board            (clk_board),
    .rst                  (sys_rst),
    .en_mic               (en_mic),
    .sync_to_video        (sync_to_video),
    .mic_clk              (mic_clk),
    .mic_data             (mic_data),
    .mic_ws               (mic_ws),
    .slow_sys_clk         (slow_sys_clk),
    .pcm_valid            (pcm_valid),
    .pcm_data             (pcm_data)
  );

  audio_wr_burst_afifo i_audio_wr_burst_fifo (
    .wr_rst               (sys_rst),
    .wr_clk               (slow_sys_clk),
    .wr_vld_i             (pcm_valid),
    .wr_rdy_o             (),
    .wr_data_i            (pcm_data),
    .rd_rst               (sys_rst),
    .rd_clk               (sys_clk),
    .burst_avail          (a_burst_avail),
    .burst_rd_en          (a_rd_en),
    .burst_rd_data        (a_rd_data),
    .err_bfifo_full       (err_abfifo_full)
  );  
  `else
  assign a_burst_avail = 1'b0;
  `endif

  gr_wr_burst_afifo gr_wr_burst_fifo (
    .wr_rst               (reg_rst),
    .wr_clk               (clk_board),
    .wr_vld_i             (gr_wr_en),
    .wr_rdy_o             (),
    .wr_data_i            (gr_wr_data),
    .rd_rst               (sys_rst),
    .rd_clk               (sys_clk),
    .burst_avail          (gr_burst_avail),
    .burst_rd_en          (gr_rd_en),
    .burst_rd_data        (gr_rd_data),
    .err_bfifo_full       ()
  );  
  
  `ifdef EN_DEBUG_CNTR
  stat #(
    .CLKFREQ_HZ           (42000000)
  ) dbg_cam_stat (
    .clk                  (cam_clk),
    .rst                  (async_rst),
    `ifdef DISABLE_CAMERA                     
    .vsync                (bar_vs),
    .href                 (bar_href),
    `else                                     
    .vsync                (cam_vsync),
    .href                 (cam_href),
    `endif
    .frm_per_sec          (cam_frm_per_sec),
    .total_frm            (cam_total_frm),
    .total_byte           (cam_total_byte),
    .lines_per_frm        (cam_lines_per_frm),
    .bytes_per_line       (cam_bytes_per_line),
    .bytes_per_frm        (cam_bytes_per_frm),
    .frm_lt_512k_err      (cam_frm_lt_512k_err)
  );
  `endif
  
  arbiter #(
    `ifdef MK11
    .MEM_SIZE             (2 * 32 * 1024 * 1024),
    `else
    .MEM_SIZE             (1 * 32 * 1024 * 1024),
    `endif
    .DQ_WIDTH             (DQ_WIDTH),
    .PSRAM_WIDTH          (PSRAM_WIDTH),
    .Fixed_Latency_Enable (Fixed_Latency_Enable),
    .RL                   (RL),
    .Drive_Strength       (Drive_Strength),
    .PASR                 (PASR),
    .ADDR_WIDTH           (ADDR_WIDTH),
    .WL                   (WL),
    .Refresh_Rate         (Refresh_Rate),
    .Power_Down           (Power_Down),
    .DQ_MODE              (DQ_MODE),
    .RBX                  (RBX),
    .Burst_Type           (Burst_Type),
    .Burst_Length         (Burst_Length)
  ) i_arbiter (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .resume_fill          (resume_fill),
    .rd_audio             (rd_audio),
    .capt_audio           (capt_audio),
    .capt_video           (capt_video),
    .capt_frm             (capt_frm),
    .capt_en              (capt_en),
    .discard_cbuf         (discard_cbuf),
    .rep_rate_control     (rep_rate_control),
    .replay_toggle        (replay_toggle),
    .en_playback          (en_playback),
    .en_graphics          (en_graphics),
    .graphics_swap_toggle (graphics_swap_toggle),
    .en_mic               (en_mic),
    .en_zoom              (en_zoom),
    .en_luma_cor          (en_luma_cor),
    .sel_zoom_mode        (sel_zoom_mode),
    .v_burst_avail        (v_burst_avail),
    .v_rd_en              (v_rd_en),
    .v_rd_data            (v_rd_data),
    .a_burst_avail        (a_burst_avail),
    .a_rd_en              (a_rd_en),
    .a_rd_data            (a_rd_data),
    .gr_wr_base           (gr_wr_base),
    .gr_wr_base_rd        (gr_wr_base_rd),
    .gr_wr_base_vld       (gr_wr_base_vld),
    .gr_burst_avail       (gr_burst_avail),
    .gr_rd_en             (gr_rd_en),
    .gr_rd_data           (gr_rd_data),
    .mem_addr             (mem_addr),
    .mem_cmd              (mem_cmd),
    .mem_cmd_en           (mem_cmd_en),
    .mem_wr_data          (mem_wr_data),
    .mem_wr_en            (mem_wr_en),
    .mem_cmd_rdy          (mem_cmd_rdy),
    .mem_rd_data          (mem_rd_data),
    .mem_rd_data_valid    (mem_rd_data_valid),
    .mem_data_mask        (mem_data_mask),
    .mem_burst_num        (mem_burst_num),
    .o_rpl_2x_done        (o_rpl_2x_done),
    .disp_avail           (disp_avail),
    .rfifo_full           (rd_bfifo_afull),
    .rfifo_wr_en          (rd_bfifo_wr_en),
    .rfifo_wr_data        (rd_bfifo_wr_data),
    .rd_ctrl_req          (rd_ctrl_req),
    .rd_ctrl_data         (rd_ctrl_data),
    .c_frm_len            (c_frm_len),
    .c_sel_zoom_mode      (c_sel_zoom_mode),
    .c_en_zoom            (c_en_zoom),
    .c_en_luma_cor        (c_en_luma_cor),
    .c_rd_video_buf       (c_rd_video_buf),
    .c_rd_frm_buf         (c_rd_frm_buf),
    .c_rd_audio_buf       (c_rd_audio_buf),
    .c_buf_size           (c_buf_size),
    .cfifo_afull          (cfifo_afull),
    .cfifo_wr_en          (cfifo_wr_en),
    .cfifo_wr_data        (cfifo_wr_data),
    .o_buf_avail(o_buf_avail),
    .c_buf_avail(c_buf_avail),
    .o_frm_avail(o_frm_avail),
    .c_frm_avail(c_frm_avail),
	.dbg_mrb_err          (dbg_mrb_err)
  );
  
//  `ifdef MK11
//  assign mem_addr[25] = 1'b0;
//  `else
//  `endif
  
  //================================================
  // PSRAM Memory Controller
  //================================================
  `ifdef MK11
  apsram_top u_psram_top (
    .memory_clk           (clk_80mhz),
  `else
  psram_memory_interface_top i_psram_memory_interface_top (
    .memory_clk           (clk_80mhz),
    .memory_clk_p         (clk_80mhz), 
  `endif
    .clk                  (clk_board),
    .clk_out              (sys_clk),
    .pll_lock             (mem_pll_lock),
    .rst_n                (mem_async_rst_n),
    .O_apsram_ck          (mem_clk),
    .IO_apsram_dqsm       (mem_dqs_mask),
    .IO_apsram_dq         (mem_dq),
    .O_apsram_cs_n        (mem_ce_n),
    .init_calib           (mem_init_done),
    .addr                 (mem_addr),
    .cmd                  (mem_cmd),
    .cmd_en               (mem_cmd_en),
    .wr_data              (mem_wr_data),
    .wr_en                (mem_wr_en),
    .cmd_rdy              (mem_cmd_rdy),
    .rd_data              (mem_rd_data),
    .rd_data_valid        (mem_rd_data_valid),
    .data_mask            (mem_data_mask),
    .burst_num            (mem_burst_num)
  );

  rd_burst_sfifo i_rd_burst_sfifo (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .afull                (rd_bfifo_afull),
    .wr_en                (rd_bfifo_wr_en),
    .wr_data              (rd_bfifo_wr_data),
    .ds_rdy               (trim_rdy),
    .burst_vld            (rd_burst_vld),
    .burst_rd_data        (rd_burst_data),
    .err_bfifo_full       (err_rd_vbfifo_full)
  );
  
  //================================================
  // Uncompress here
  //================================================
  // TBD
  
  // Strip off the Pixels for Zoom
  frm_trim i_frm_trim (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    
	//.en_zoom_i              (en_zoom),
    //.en_luma_cor_i          (en_luma_cor),
    //.sel_zoom_mode_i        (sel_zoom_mode),

    .en_luma_cor_i          (rd_ctrl_data[3]),
	.en_zoom_i              (rd_ctrl_data[2]),
    .sel_zoom_mode_i        (rd_ctrl_data[1:0]),
	
    .sof                  (rd_burst_data[32]),
    .eof                  (rd_burst_data[33]),
    .din_vld              (rd_burst_vld),
    .din_rdy              (trim_rdy),
    .trim_zoom_ctrl       (trim_zoom_ctrl),
    .sof_out              (trim_sof),
    .eof_out              (trim_eof),
    .frm_len_out          (trim_frm_len),
    .dout_vld             (trim_vld),
    .dout_rdy             (zoom_rdy)
  );

  zoom i_zoom (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .en                   (trim_zoom_ctrl[2]),
    .sel_zoom_mode        (trim_zoom_ctrl[1:0]),
    .rd_ctrl_req          (rd_ctrl_req),
    .us_vld               (trim_vld),
    .zoom_rdy             (zoom_rdy),
    .us_rd_data           ({rd_burst_data[35:34], trim_eof, trim_sof, rd_burst_data[31:0]}),
    .ds_vld               (zoom_vld),
    .ds_rdy               (luma_rdy),
    .ds_rd_data           (zoom_data)
  );

  luma_correction i_luma_correction (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .en                   (trim_zoom_ctrl[3]),
    .en_zoom              (trim_zoom_ctrl[2]),
    .sel_zoom_mode        (trim_zoom_ctrl[1:0]),
    .us_vld               (zoom_vld),
    .luma_rdy             (luma_rdy),
    .us_rd_data           (zoom_data),
    // Exclude RB Shift
	.ds_vld               (luma_vld),
    .ds_rdy               (disp_rdy),
    .ds_rd_data           (luma_data)
	// Include RB Shift
    ///.ds_vld               (luma_vld),
    ///.ds_rdy               (rb_rdy),
    ///.ds_rd_data           (luma_data)
  );

  rb_shift i_rb_shift (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .en                   (en_rb_shift),
    .vld_i                (luma_vld),
    .rb_rdy               (rb_rdy),
    .din                  (luma_data),
    .vld_o                (rb_vld),
    .ds_rdy               (disp_rdy),
    .dout                 (rb_data)
  );
  
  disp_if i_disp_if (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .disp_bars            (disp_bars),
    .disp_busy            (disp_busy),
    .disp_cam             (disp_cam),
    // Include RB Shift
    //.burst_vld            (rb_vld),
    //.disp_fifo_rdy        (disp_rdy),
    //.burst_rd_data        (rb_data),
    // Exclude RB Shift
    .burst_vld            (luma_vld),
    .disp_fifo_rdy        (disp_rdy),
    .burst_rd_data        (luma_data),
    .disp_clk             (clk_27mhz),
    .disp_clk_180         (clk_27mhz_180),
    .disp_rst             (disp_rst),
    .mclk                 (disp_mclk),
    .hsync_n              (disp_hsync),
    .vsync_n              (disp_vsync),
    .href                 (disp_href),
    .data                 (disp_data),
    .disp_fifo_underrun   (disp_fifo_underrun),
    .disp_fifo_overrun    (disp_fifo_overrun)
  );
  
  `ifdef EN_DEBUG_CNTR
  stat #(
    .CLKFREQ_HZ           (27000000),
    .STAT_FOR_DISP        (1'b1)
  ) dbg_disp_stat (
    .clk                  (clk_27mhz),
    .rst                  (async_rst),
    .vsync                (disp_vsync),
    .href                 (disp_href),
    .frm_per_sec          (disp_frm_per_sec),
    .total_frm            (disp_total_frm),
    .total_byte           (disp_total_byte),
    .lines_per_frm        (disp_lines_per_frm),
    .bytes_per_line       (disp_bytes_per_line),
    .bytes_per_frm        (disp_bytes_per_frm),
    .frm_lt_512k_err      (disp_frm_lt_512k_err)
  );
  `endif

   spi_api i_spi_api(
     .clk                  (clk_board),
     .reset                (reg_rst),
     .SCLK                 (SCLK),
     .MOSI                 (MOSI),
     .MISO                 (MISO),
     .SS                   (SS),
     .en_xclk              (en_xclk),
     .en_cam               (en_cam),
     .en_playback          (en_playback),
     .en_zoom              (en_zoom),
     .en_luma_cor          (en_luma_cor),
     .sel_zoom_mode        (sel_zoom_mode),
     .replay_toggle        (replay_toggle),
     .en_graphics          (en_graphics),
     .graphics_base_wren   (graphics_base_wren),
     .graphics_base_val    (graphics_base_val),
     .graphics_swap_toggle (graphics_swap_toggle),
     .en_mic               (en_mic),
     .sync_to_video        (sync_to_video),
     .en_rb_shift          (en_rb_shift),
     .disp_bars            (disp_bars),
     .disp_busy            (disp_busy),
     .disp_cam             (disp_cam),
     .mem_control          (),
     .discard_cbuf         (discard_cbuf),
     .clr_chksm            (clr_chksm),
     .resume_fill          (resume_fill),
     .rd_audio             (rd_audio),
     .capt_audio           (capt_audio),
     .capt_video           (capt_video),
     .capt_frm             (capt_frm),
     .capt_en              (capt_en),
     .rep_rate_control     (rep_rate_control),
     .burst_wr_rdy         (~gr_base_fifo_full),
     .burst_wr_en          (gr_wr_en),
     .burst_wdata          (gr_wr_data),
     .burst_rd_eof         (eob),
     .burst_rd_cnt         (cfifo_rd_cnt),
     .burst_rd_en          (cfifo_rd_en),
     .burst_rd_data        (cfifo_rd_data),
     .o_buf_avail(o_buf_avail),
     .c_buf_avail(c_buf_avail),
     .o_frm_avail(o_frm_avail),
     .c_frm_avail(c_frm_avail)
   );

   wire gr_base_fifo_empty, gr_base_fifo_full;

   dist_afifo_fwft_32x8 i_graphics_base_fifo (
	.Data(graphics_base_val), //input [31:0] Data
	.WrReset(reg_rst), //input WrReset
	.RdReset(sys_rst), //input RdReset
	.WrClk(clk_board), //input WrClk
	.RdClk(sys_clk), //input RdClk
	.WrEn(graphics_base_wren), //input WrEn
	.RdEn(gr_wr_base_rd),
	.Q(gr_wr_base),
	.Empty(gr_base_fifo_empty),
	.Full(gr_base_fifo_full)
   );			  

   assign gr_wr_base_vld = ~gr_base_fifo_empty;
			  
  //wire                              rb_wr_en;
  //wire [`DSIZE-1:0]                 rb_wr_data;  
  //rb_shift i_rb_shift_capt (
  //  .rst                  (sys_rst),
  //  .clk                  (sys_clk),
  //  .en                   (1'b1),//en_rb_shift),
  //  .vld_i                (cfifo_wr_en),
  //  .din                  (cfifo_wr_data),
  //  .vld_o                (rb_wr_en),
  //  .dout                 (rb_wr_data)
  //);
  capt_fifo_if i_capt_fifo_if (
    .rst                  (sys_rst),
    .clk                  (sys_clk),
    .cfifo_afull          (cfifo_afull),
    .cfifo_wr_en          (cfifo_wr_en),
    .cfifo_wr_data        (cfifo_wr_data),
    //.cfifo_wr_en          (rb_wr_en),
    //.cfifo_wr_data        (rb_wr_data),
    .clk_reg              (clk_board),
    .rst_reg              (reg_rst),
    .clr_chksm            (clr_chksm),
    .resume_fill          (resume_fill),
    .cfifo_rd_vld         (cfifo_rd_vld),
  `ifdef SIM_ENABLE
    .cfifo_rd_en          (cfifo_rd_vld),
  `else
    .cfifo_rd_en          (cfifo_rd_en),
  `endif
    .cfifo_rd_cnt         (cfifo_rd_cnt),
    .cfifo_rd_data        (cfifo_rd_data),
    .sob                  (sob),
    .eob                  (eob),
    .capt_byte_cntr       (capt_byte_cntr),
    .capt_frm_chk_sum     (capt_frm_chk_sum),
    .capt_fifo_underrun   (capt_fifo_underrun),
    .capt_fifo_overrun    (capt_fifo_overrun)
  );  
  
endmodule

`default_nettype wire