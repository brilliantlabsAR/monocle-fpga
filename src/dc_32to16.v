module dc_32to16 (
  clk,
  rst,
  //Slave Interface
  s_data_i,
  s_sof,
  s_eof,
  s_vld_i,
  s_rdy_o,
  //Master Interface
  m_data_o,
  m_sof,
  m_eof,
  m_vld_o,
  m_rdy_i
);

  input  wire                       rst;
  input  wire                       clk;
  input  wire [31:0]                s_data_i;
  input  wire                       s_sof;
  input  wire                       s_eof;
  input  wire                       s_vld_i;
  output wire                       s_rdy_o;
  output wire [15:0]                m_data_o;
  output wire                       m_sof;
  output wire                       m_eof;
  output wire                       m_vld_o;
  input  wire                       m_rdy_i;

  // Parameters
  
  reg                               data_cntr;

  always @(posedge clk) begin
    if (rst) begin
      data_cntr <= 1'b0;
    end else if (s_vld_i && m_rdy_i) begin
      data_cntr <= data_cntr + 1'b1;
    end
  end
  
  assign s_rdy_o = m_rdy_i && data_cntr == 1'b1 ? 1'b1 : 1'b0; 
  
  assign m_data_o = data_cntr == 1'b0 ? s_data_i[15:0] :
                                        s_data_i[31:16];
  assign m_vld_o  = s_vld_i || data_cntr == 1'b1 ? 1'b1 : 1'b0;
  
  assign m_sof    = m_vld_o && data_cntr == 1'b0 ? s_sof : 1'b0;
  assign m_eof    = m_vld_o && data_cntr == 1'b1 ? s_eof : 1'b0;
  
endmodule
