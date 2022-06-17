`default_nettype none

`include "defines.v"

module dc_8to32 (
  rst,
  clk,
  // Slave Interface
  s_vld_i,
  s_rdy_o,
  s_data_i,
  s_sof_i,
  s_eof_i,
  // Master Interface
  m_vld_o,
  m_rdy_i,
  m_data_o,
  m_sof_o,
  m_eof_o,
  m_be_o
);
  
  input  wire                       clk;
  input  wire                       rst;
  //Slave Interface   
  input  wire                       s_vld_i;
  output wire                       s_rdy_o;
  input  wire [7:0]                 s_data_i;
  input  wire                       s_sof_i;
  input  wire                       s_eof_i;
  //Master Interface
  output wire                       m_vld_o;
  input  wire                       m_rdy_i;
  output reg  [31:0]                m_data_o;
  output wire                       m_sof_o;
  output reg                        m_eof_o;
  output wire [1:0]                 m_be_o;
  
  // Local Parameters
  
  // Internal Signals
  reg                               rst_r;
  reg                               full;
  reg                               lch_sof;
  reg  [1:0]                        idx;
  wire                              wrap;
  wire                              wr;
  wire                              rd;
  
  
  assign wrap = (idx == 2'b11) | s_eof_i;

  //*** For vld/rdy interface
  assign wr = s_vld_i & s_rdy_o;
  assign rd = m_vld_o & m_rdy_i;
  
  ////*** For Burst avail interface
  //assign wr = s_rdy_o;
  //assign rd = m_rdy_i;
  
  assign s_rdy_o = !((full & !rd) | rst_r);

  assign m_vld_o = full;
  assign m_be_o    = s_eof_i ? idx : 2'b11;
  assign m_sof_o   = lch_sof;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      full <= 1'b0;
      idx <= 0;
      rst_r <= 1'b1;
      m_data_o <= 'b0;
      lch_sof <= 1'b0;
    end else begin
      if (wr & wrap & !rd)
        full <= 1'b1;
      else if (rd)
        full <= 1'b0;
     
     if (wr)
       if (wrap)
         idx <= 0;
       else 
         idx <= idx + 1'b1;

     if (wr)
       m_data_o[idx*8+:8] <= s_data_i;
     
     if (full)
       lch_sof <= 1'b0;
     else if (s_sof_i && idx == 2'b0)
       lch_sof <= 1'b1;
     
     m_eof_o <= s_eof_i;
     rst_r <= 1'b0;
    end
  end
  
endmodule
`default_nettype wire