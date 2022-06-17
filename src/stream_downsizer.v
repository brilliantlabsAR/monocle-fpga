module stream_downsizer #(
  parameter                         DW_OUT = 0,
  parameter                         SCALE = 0
)(
  input                             clk,
  input                             rst,
  //Slave Interface   
  input [DW_OUT*SCALE-1:0]          s_data_i,
  input                             s_valid_i,
  output                            s_ready_o,
  //Master Interface
  output [DW_OUT-1:0]               m_data_o,
  output                            m_valid_o,
  input                             m_ready_i
);

  reg                               rst_r;
  
  reg                               full;
  reg  [$clog2(DW_OUT*SCALE)-1:0]   idx;
  reg  [DW_OUT*SCALE-1:0]           data;
  
  wire                              wr;
  wire                              rd;
  wire                              wrap;
  
  assign wr = s_valid_i & s_ready_o;
  assign rd = m_valid_o & m_ready_i;
  assign wrap = (idx == SCALE-1) & rd;
  
  assign s_ready_o = (((idx == 0) & !full) | (wrap)) & !rst_r;
  
  assign m_data_o = data[idx*DW_OUT+:DW_OUT];
  assign m_valid_o = full;
  
   always @(posedge clk) begin
     if (wr & !rd)
       full <= 1'b1;
     else if (!wr & rd & wrap)
       full <= 1'b0;

     if (wr)
       data <= s_data_i;
     
     if (rd) begin
       if(wrap)
         idx <= 0;
       else
         idx <= idx + 1'b1;
     end
     
     rst_r <= 1'b0;
     
     if (rst) begin
       idx <= 0;
       full <= 1'b0;
       rst_r <= 1'b1;
       //m_valid_o <= 1'b0;
     end
   end
endmodule
