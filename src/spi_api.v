`include "defines.v"

module spi_api(
  input 		     clk,
  input 		     reset,

  input 		     burst_rd_eof,
  input [11:0] 		     burst_rd_cnt,
  input [7:0] 		     burst_rd_data,
  output 		     burst_rd_en,

  output 		     rst_sw,
  output reg 		     en_xclk,
  output 		     en_cam,
  output 		     en_playback,
  output reg 		     en_zoom,
  output reg 		     en_luma_cor,
  output [1:0] 		     sel_zoom_mode,
  output reg 		     replay_toggle,

  output 		     en_graphics,
  output 		     graphics_base_wren,
  output [31:0] 	     graphics_base_val,
  output reg 		     graphics_swap_toggle,
	       
  output reg 		     en_mic,
  output reg 		     sync_to_video,

  output reg 		     en_rb_shift,
  output 		     disp_bars,
  output 		     disp_busy,
  output 		     disp_cam,

  output reg [`REG_SIZE-1:0] mem_control,
  output reg 		     discard_cbuf,
  output reg 		     clr_chksm,
  output reg 		     resume_fill,
  output reg 		     rd_audio,
  output reg 		     capt_audio,
  output reg 		     capt_video,
  output reg 		     capt_frm,
  output reg 		     capt_en,
  output reg [4:0] 	     rep_rate_control,

  input 		     burst_wr_rdy,
  output 		     burst_wr_en,
  output reg [15:0] 	     burst_wdata,

  input 		     o_buf_avail,
  input 		     c_buf_avail,
  input 		     o_frm_avail,
  input 		     c_frm_avail,
	       
  input 		     SCLK,
  input 		     MOSI,
  output 		     MISO,
  input 		     SS
);

   localparam integer 	     GR_BUF_SIZE = 640*400;

   always @(posedge clk)
     if (reset) begin
       en_luma_cor      <= 1'b0;
       sync_to_video    <= 1'b0;
       en_mic           <= 1'b0;
       en_rb_shift      <= 1'b0;
       mem_control      <= 8'h02;
       rd_audio         <= 1'b0;
       capt_audio       <= 1'b0;
       capt_video       <= 1'b0;
       rep_rate_control <= 5'h3;
     end

   wire [7:0] 	spi_data_in;
   wire [7:0] 	spi_data_out;
   wire 	spi_data_oe;

   wire 	cmd_strobe, cmd_next, cmd_start;


   ////////// MCU SPI interface

   spi_slave #(
     .FIRST_BIT(0)
   ) spi_u (
     .reset(reset),
     .clk(clk),
     .api_din(spi_data_in),
     .api_dout(spi_data_out),
     .api_strobe(cmd_strobe),
     .api_start(cmd_start),
     .api_next(cmd_next),
     .sclk(SCLK),
     .mosi(MOSI),
     .miso(MISO),
     .ssn(SS)
   );

   reg 		end_capture;

   wire [31:0] 	system_status_val_o_u_t;
   wire [15:0] 	system_ID_val_o_u_t;
   wire [23:0] 	system_version_val_o_u_t;

   wire [15:0] 	capture_status_val_o_u_t;
   wire 	capture_memout_read_rdy;
   wire 	capture_memout_read_req;
   wire [7:0] 	capture_memout_val_o_u_t;
   wire 	capture_apisig_write_req;
   wire [7:0] 	capture_apisig_val;

   wire 	graphics_memin_write_rdy;
   wire 	graphics_memin_write_req;
   wire [7:0] 	graphics_memin_val;
   wire 	graphics_apisig_write_req;
   wire [7:0] 	graphics_apisig_val;
   wire 	graphics_base_wren_i;
   wire [31:0] 	graphics_base_val_i;
   

   wire [7:0] 	camera_zoom_val;
   wire [7:0] 	camera_status_val_o_u_t;
   wire [31:0] 	camera_frame_val_o_u_t;
   wire 	camera_histogram_read_rdy;
   wire 	camera_histogram_read_req;
   wire [7:0] 	camera_histogram_val_o_u_t;
   wire 	camera_config_write_rdy;
   wire 	camera_config_write_req;
   wire [7:0] 	camera_config_val;
   wire 	camera_apisig_write_req;
   wire [7:0] 	camera_apisig_val;

   wire [7:0] 	video_status_val_o_u_t;
   wire 	video_apisig_write_req;
   wire [7:0] 	video_apisig_val;

   wire [7:0] 	display_status_val_o_u_t;
   wire 	display_apisig_write_req;
   wire [7:0] 	display_apisig_val;

   monocle_api i_api (
     .reset(reset),
     .clk(clk),
     .p_ext_api_start(cmd_start),
     .p_ext_api_strobe(cmd_strobe),
     .p_ext_api_next(cmd_next),
     .p_ext_api_din(spi_data_in),
     .p_ext_api_dout(spi_data_out),
     .p_ext_api_oe(spi_data_oe),
     .p_system_status_val_o_u_t(system_status_val_o_u_t),
     .p_system_ID_val_o_u_t(system_ID_val_o_u_t),
     .p_system_version_val_o_u_t(system_version_val_o_u_t),
     .p_capture_status_val_o_u_t(capture_status_val_o_u_t),
     .p_capture_memout_read_rdy(capture_memout_read_rdy),
     .p_capture_memout_read_req(capture_memout_read_req),
     .p_capture_memout_val_o_u_t(capture_memout_val_o_u_t),
     .p_capture_apisig_write_rdy(1'b1),
     .p_capture_apisig_write_req(capture_apisig_write_req),
     .p_capture_apisig_val(capture_apisig_val),
     .p_graphics_base_wren(graphics_base_wren_i),
     .p_graphics_base_val(graphics_base_val_i),
     .p_graphics_memin_write_rdy(graphics_memin_write_rdy),
     .p_graphics_memin_write_req(graphics_memin_write_req),
     .p_graphics_memin_val(graphics_memin_val),
     .p_graphics_apisig_write_rdy(1'b1),
     .p_graphics_apisig_write_req(graphics_apisig_write_req),
     .p_graphics_apisig_val(graphics_apisig_val),
     .p_camera_status_val_o_u_t(camera_status_val_o_u_t),
     .p_camera_frame_val_o_u_t(camera_frame_val_o_u_t),
     .p_camera_zoom_val(camera_zoom_val),
     .p_camera_histogram_read_rdy(camera_histogram_read_rdy),
     .p_camera_histogram_read_req(camera_histogram_read_req),
     .p_camera_histogram_val_o_u_t(camera_histogram_val_o_u_t),
     .p_camera_config_write_rdy(camera_config_write_rdy),
     .p_camera_config_write_req(camera_config_write_req),
     .p_camera_config_val(camera_config_val),
     .p_camera_apisig_write_rdy(1'b1),
     .p_camera_apisig_write_req(camera_apisig_write_req),
     .p_camera_apisig_val(camera_apisig_val),
     .p_video_status_val_o_u_t(video_status_val_o_u_t),
     .p_video_apisig_write_rdy(1'b1),
     .p_video_apisig_write_req(video_apisig_write_req),
     .p_video_apisig_val(video_apisig_val),
     .p_display_status_val_o_u_t(display_status_val_o_u_t),
     .p_display_apisig_write_rdy(1'b1),
     .p_display_apisig_write_req(display_apisig_write_req),
     .p_display_apisig_val(display_apisig_val)
   );

   assign rst_sw = 1'b0;

   //////// SYSTEM

   assign system_ID_val_o_u_t = 16'h4b07;
   assign system_version_val_o_u_t = 24'h221206;


   //////// CAMERA

   wire 	capt_req;
   
   reg 		cam_on, xclk_on;

   always @(posedge clk)
     if (reset)
       xclk_on <= 1'b0;
     else if (camera_apisig_write_req && camera_apisig_val[3:1] == 3'b100)
       xclk_on <= camera_apisig_val[0];

   assign en_xclk = xclk_on;

   assign capt_req = camera_apisig_write_req && camera_apisig_val[3:0] == 4'b0110;

   always @(posedge clk)
     if (reset) begin
	cam_on <= 1'b0;
	clr_chksm        <= 1'b0;
	resume_fill      <= 1'b0;
	capt_frm         <= 1'b0;
	capt_en          <= 1'b0;
	discard_cbuf     <= 1'b0;
     end else if (camera_apisig_write_req && camera_apisig_val[3:1] == 3'b010) begin
	cam_on <= xclk_on & camera_apisig_val[0];
	clr_chksm <= xclk_on & camera_apisig_val[0];
	resume_fill <= xclk_on & camera_apisig_val[0];
	capt_en <= 1'b0;
	discard_cbuf <= 1'b0;
     end else if (capt_req) begin
	cam_on <= xclk_on;
	clr_chksm <= 1'b0;
	resume_fill <= 1'b0;
	capt_frm <= xclk_on;
	capt_en <= xclk_on;
	discard_cbuf <= 1'b0;
     end else if (end_capture) begin
	cam_on <= 1'b0;
	clr_chksm        <= 1'b0;
	resume_fill      <= 1'b0;
	capt_frm         <= 1'b0;
	capt_en          <= 1'b0;
	discard_cbuf     <= 1'b1;
     end

   assign en_cam = cam_on;

   always @(posedge clk)
     if (reset)
       en_zoom <= 1'b0;
     else
       en_zoom <= camera_zoom_val[1:0] != 2'b00;

   assign camera_status_val_o_u_t = {2'b00, o_frm_avail, o_buf_avail, c_frm_avail, c_buf_avail, cam_on, xclk_on};
   assign sel_zoom_mode = camera_status_val_o_u_t[1:0];


   // not supported on monocle
   assign camera_config_write_req = 1'b0;

   //////// VIDEO

   reg video_on;

   wire replay_req;
   
   assign replay_req = video_apisig_write_req && video_apisig_val[2:0] == 3'b111;

   always @(posedge clk)
     if (reset)
       replay_toggle <= 1'b0;
     else if (replay_req & video_on)
       replay_toggle <= ~replay_toggle;

   always @(posedge clk)
     if (reset)
	video_on <= 1'b0;
     else if (video_apisig_write_req && video_apisig_val[3:1] == 3'b010)
	video_on <= cam_on & video_apisig_val[0];

   assign en_playback = video_on;

   
   //////// GRAPHICS

   wire clear_req, clear_end;
   reg clearing;
   reg [17:0] clear_cnt;
   reg memin_wr_en;
   reg memin_cntr;
   
   assign clear_req = graphics_apisig_write_req && graphics_apisig_val[2:0] == 3'b110;
   assign swap_req = graphics_apisig_write_req && graphics_apisig_val[2:0] == 3'b111;

   //// Swap operation

   always @(posedge clk)
     if (reset)
       graphics_swap_toggle <= 1'b0;
     else if (swap_req)
       graphics_swap_toggle <= ~graphics_swap_toggle;

   //// Clear operation
   
   always @(posedge clk)
     if (reset)
       clearing <= 1'b0;
     else if (clear_req)
       clearing <= 1'b1;
     else if (clear_end && burst_wr_rdy)
       clearing <= 1'b0;

   always @(posedge clk)
     if (clear_req)
       clear_cnt <= 18'd0;
     else if (clearing && burst_wr_rdy)
       clear_cnt <= clear_cnt + 18'd1;

   assign clear_end = (clear_cnt == (GR_BUF_SIZE-1));

   ///// MCU write operation

   assign graphics_memin_write_req = 1'b1;

   always @(posedge clk)
     if (reset)
       memin_cntr <= 1'b0;
     else if (graphics_memin_write_rdy)
       memin_cntr <= ~memin_cntr;
   
   always @(posedge clk)
     if (reset)
       memin_wr_en <= 1'b0;
     else 
       memin_wr_en <= graphics_memin_write_rdy & memin_cntr;

   //// Burst data

   assign burst_wr_en = clearing ? burst_wr_rdy : memin_wr_en;
   
   always @(posedge clk)
     if (clear_req)
       burst_wdata <= 16'h0000;
     else if (graphics_memin_write_rdy)
       burst_wdata <= { burst_wdata[7:0], graphics_memin_val };

   //// Write base
   assign graphics_base_wren = graphics_base_wren_i | clear_req;
   assign graphics_base_val = clear_req ? 32'd0 : graphics_base_val_i;

   
   //////// DISPLAY

   reg graphics_on;

   always @(posedge clk)
     if (reset)
       graphics_on <= 1'b0;
     else if (graphics_apisig_write_req && graphics_apisig_val[2:1] == 2'b10)
       graphics_on <= graphics_apisig_val[0];

   assign en_graphics = graphics_on;
   

   //////// CAPTURE

   reg capt_done;

   always @(posedge clk)
     if (reset)
       end_capture <= 1'b0;
     else
       end_capture <= burst_rd_eof & capture_memout_read_req;

   always @(posedge clk)
     if (reset || capt_req)
       capt_done <= 1'b0;
     else if (burst_rd_eof & capture_memout_read_req)
       capt_done <= 1'b1;

   assign capture_status_val_o_u_t = {3'b000, capt_done, burst_rd_cnt};

   assign capture_memout_read_rdy = 1'b1;
   assign burst_rd_en = capture_memout_read_req;

   assign capture_memout_val_o_u_t = burst_rd_data;

   
   //////// Misc
   
   assign disp_busy = 1'b0;
   assign disp_bars = ~(video_on | graphics_on);
   assign disp_cam = video_on | graphics_on;

endmodule
