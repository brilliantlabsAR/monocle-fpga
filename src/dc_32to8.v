module dc_32to8 (
  clk,
  rst,
  //Slave Interface
  s_vld_i,
  s_data_i,
  s_sof,
  s_eof_sb,
  s_rdy_o,
  //Master Interface
  m_vld_o,
  m_data_o,
  m_sof,
  m_eof_sb,
  m_rdy_i
);

  input  wire                       rst;
  input  wire                       clk;
  input  wire [31:0]                s_data_i;
  input  wire                       s_sof;
  input  wire [2:0]                 s_eof_sb;
  input  wire                       s_vld_i;
  output reg                        s_rdy_o;
  output wire [7:0]                 m_data_o;
  output wire                       m_sof;
  output wire [2:0]                 m_eof_sb;
  output wire                       m_vld_o;
  output wire                       m_rdy_i;
  
  // Parameters
  
  reg  [1:0]                        data_cntr;

  always @(posedge clk) begin
    if (rst) begin
      data_cntr <= 2'b0;
    //end else if (s_vld_i && m_rdy_i) begin //For vld/rdy interface
    end else if (m_rdy_i) begin //For burst avail interface
      data_cntr <= data_cntr + 2'b1;
    end
  end
  
  assign s_rdy_o = m_rdy_i && data_cntr == 2'b11 ? 1'b1 : 1'b0; 

  assign m_data_o = data_cntr == 2'b11 ? s_data_i[24+:8] :
                    data_cntr == 2'b10 ? s_data_i[16+:8] :
                    data_cntr == 2'b01 ? s_data_i[8+:8]  :
                                         s_data_i[0+:8] ;
  assign m_vld_o  = s_vld_i;
  
  assign m_sof    = m_vld_o && data_cntr == 2'b00 ? s_sof : 1'b0;
  assign m_eof_sb = m_vld_o && data_cntr == 2'b11 ? s_eof_sb : 1'b0;
  
endmodule
