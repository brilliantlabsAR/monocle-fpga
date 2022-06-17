`default_nettype none

`include "defines.v"

module frm_trim (
  rst,
  clk,
  en_zoom_i,
  en_luma_cor_i,
  sel_zoom_mode_i,
  //zoom_ctrl,
  sof,
  eof,
  din_vld,
  din_rdy,
  trim_zoom_ctrl,
  sof_out,
  eof_out,
  frm_len_out,
  dout_vld,
  dout_rdy
);
  
  // Camera Interface
  input  wire                       rst;
  input  wire                       clk;
  input  wire                       en_zoom_i;
  input  wire                       en_luma_cor_i;
  input  wire [1:0]                 sel_zoom_mode_i;
  //input  wire [35:0]                zoom_ctrl;
  input  wire                       sof;
  input  wire                       eof;
  input  wire                       din_vld;
  output wire                       din_rdy;
  output wire [35:0]                trim_zoom_ctrl;
  output wire                       sof_out;
  output wire                       eof_out;
  output wire [18:0]                frm_len_out;
  output wire                       dout_vld;
  input  wire                       dout_rdy;

  // Local Parameters
  localparam  IDLE                = 7'b0000001;
  localparam  DROP_UP_LINE        = 7'b0000010;
  localparam  DROP_LEFT_COL       = 7'b0000100;
  localparam  USEFUL_COL          = 7'b0001000;
  localparam  DROP_RIGHT_COL      = 7'b0010000;
  localparam  DROP_DOWN_LINE      = 7'b0100000;
  localparam  FRM_DONE            = 7'b1000000;
  
  localparam  ROW_CNT_WIDTH       = $clog2(`MAX_FRM_ROW);
  localparam  COL_CNT_WIDTH       = $clog2(`MAX_FRM_COL);
  
  // Internal Signals
  reg  [6:0]                        c_state;
  reg  [6:0]                        n_state;
  reg  [18:0]                       frm_byte_cnt;
  reg  [ROW_CNT_WIDTH-1:0]          row_cntr;
  wire [ROW_CNT_WIDTH-1:0]          start_row;
  wire [ROW_CNT_WIDTH-1:0]          end_row;
  reg  [COL_CNT_WIDTH-1:0]          col_cntr;
  wire [COL_CNT_WIDTH-1:0]          start_col;
  wire [COL_CNT_WIDTH-1:0]          end_col;
  wire                              start;
  wire                              vld_col_done;
  wire                              drop_up_line_done;
  wire                              vld_row_done;
  wire                              eol;
  wire                              drop_left_col_done;
  reg                               en_d1;
  reg                               en_sync;
  reg                               mask_zoom_ctrl;
  wire                              en;
  wire [1:0]                        sel_zoom_mode;
  reg  [35:0]                       lch_zoom_ctrl;
  wire [35:0]                       zoom_ctrl;
  
  //================================================
  // Synchronizer
  //================================================
  //always@(posedge clk) begin
  //  en_d1   <= en;
  //  en_sync <= en_d1;
  //end
  
  assign zoom_ctrl = {32'b0, en_luma_cor_i, en_zoom_i, sel_zoom_mode_i};
  //assign zoom_ctrl = {9'b0, en_luma_cor_i, en_zoom_i, sel_zoom_mode_i, 23'b0};
  //                               [26],          [25],        [24:23],         [22:0]
  
  // Mask Zoom Control for very first frame
  always @(posedge clk) begin
    if (rst) begin
      lch_zoom_ctrl <= 36'b0;
    end else if(eof && din_rdy) begin // Set when no zoom
      lch_zoom_ctrl <= zoom_ctrl;
    end
  end
  
  assign en = lch_zoom_ctrl[2];
  assign sel_zoom_mode = lch_zoom_ctrl[1:0];
  
  assign start = en & sof & din_vld & din_rdy;
  
  // Row counter
  always @(posedge clk) begin
    if (rst) begin
      row_cntr <= {`MAX_FRM_ROW{1'b0}};
    end else if(eof) begin
      row_cntr <= {`MAX_FRM_ROW{1'b0}};
    end else if(en && eol) begin
      row_cntr <= row_cntr + 1;
    end
  end

  // Column counter
  always @(posedge clk) begin
    if (rst) begin
      col_cntr <= {`MAX_FRM_COL{1'b0}};
    end else if(eol) begin
      col_cntr <= {`MAX_FRM_COL{1'b0}};
    end else if(en && din_vld & din_rdy) begin
      col_cntr <= col_cntr + 4;
    end
  end
  
  
  assign start_row = sel_zoom_mode == 2'b10 ? `START_ROW_8x-1 : //8x
                     sel_zoom_mode == 2'b01 ? `START_ROW_4x-1 : //4x
                                              `START_ROW_2x-1 ; //2x
                                              
  assign start_col = sel_zoom_mode == 2'b10 ? `START_COL_8x-4 : //8x
                     sel_zoom_mode == 2'b01 ? `START_COL_4x-4 : //4x
                                              `START_COL_2x-4 ; //2x
  
  assign end_row = sel_zoom_mode == 2'b10 ? `END_ROW_8x-1 : //8x
                   sel_zoom_mode == 2'b01 ? `END_ROW_4x-1 : //4x
                                            `END_ROW_2x-1 ; //2x
                 
  assign end_col = sel_zoom_mode == 2'b10 ? `END_COL_8x-4 : //8x
                   sel_zoom_mode == 2'b01 ? `END_COL_4x-4 : //4x
                                            `END_COL_2x-4 ; //2x
                                            
  assign drop_up_line_done  = row_cntr >= start_row ? 1'b1 : 1'b0;
  assign drop_left_col_done = col_cntr >= start_col ? 1'b1 : 1'b0;
  
  assign vld_col_done = din_rdy & col_cntr >= end_col ? 1'b1 : 1'b0;
  assign vld_row_done = row_cntr >= end_row ? 1'b1 : 1'b0;
  
  assign eol = col_cntr == `MAX_FRM_COL-4 ? 1'b1 : 1'b0;
  
  
  //================================================
  // FSM for Frame Trim
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
        if (start) begin
          n_state = DROP_UP_LINE;
        end else begin
          n_state = IDLE;
        end
              
      DROP_UP_LINE:
        if (eol & drop_up_line_done) begin
          n_state = DROP_LEFT_COL;
        end else begin
          n_state = DROP_UP_LINE;
        end
      
      DROP_LEFT_COL: 
        if (drop_left_col_done) begin
          n_state = USEFUL_COL;
        end else begin
          n_state = DROP_LEFT_COL;
        end
  
      USEFUL_COL:
        if (vld_col_done) begin
          n_state = DROP_RIGHT_COL;
        end else begin
          n_state = USEFUL_COL;
        end
  
      DROP_RIGHT_COL:
        if (eol) begin
          if (vld_row_done) begin
            n_state = DROP_DOWN_LINE;
          end else begin
            n_state = DROP_LEFT_COL;
          end
        end else begin
          n_state = DROP_RIGHT_COL;
        end
  
      DROP_DOWN_LINE:
        if (eof) begin
          n_state = FRM_DONE;
        end else begin
          n_state = DROP_DOWN_LINE;
        end
  
      FRM_DONE: 
        n_state = IDLE;
                
      default: n_state = IDLE;
    endcase
  end

  assign dout_vld = en & (c_state != USEFUL_COL) ? 1'b0 : din_vld;
  assign din_rdy  = en & (c_state != USEFUL_COL) ? 1'b1 : dout_rdy;

  // Frame Length
  always@(posedge clk or posedge rst) begin
    if(rst | eof)
      frm_byte_cnt <= 19'd0;
    else if(dout_vld & dout_rdy)
      frm_byte_cnt <= frm_byte_cnt + 19'd4;
  end
  
  assign sof_out     = en ? (dout_vld & frm_byte_cnt == 19'h0 ? 1'b1 : 1'b0) : sof;
  assign eof_out     = en ? (dout_vld & vld_row_done & vld_col_done) : eof;
  
  assign frm_len_out = en ? frm_byte_cnt : `FRAME_LENGTH;
  
  assign trim_zoom_ctrl = lch_zoom_ctrl;
  
endmodule
`default_nettype wire