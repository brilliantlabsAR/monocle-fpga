module stream_upsizer #(
  parameter DW_IN = 0,
  parameter SCALE = 0,
  parameter BIG_ENDIAN = 0
)
(
  input                             clk,
  input                             rst,
  //Slave Interface   
  input [DW_IN-1:0]                 s_data_i,
  input                             s_valid_i,
  output                            s_ready_o,
  //Master Interface
  output [DW_IN*SCALE-1:0]          m_data_o,
  output                            m_valid_o,
  input                             m_ready_i
);
  
  localparam CNTR_WIDTH           = $clog2(DW_IN*SCALE);
  
  reg                               rst_r;
  reg                               full;
  reg  [$clog2(DW_IN*SCALE)-1:0]    idx;
  reg  [DW_IN*SCALE-1:0]            data;
  wire                              wrap;
  wire                              wr;
  wire                              rd;
  
  assign wrap = (idx == SCALE-1);

  assign wr = s_valid_i & s_ready_o;
  assign rd = m_valid_o & m_ready_i;
  
  assign s_ready_o = !((full & !rd) | rst_r);

  assign m_data_o = BIG_ENDIAN ? reverse(data) : data;
  assign m_valid_o = full;
 
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      full <= 1'b0;
      idx <= 0;
      rst_r <= 1'b1;
      data <= 'b0;
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
       data[idx*DW_IN+:DW_IN] <= s_data_i;

     rst_r <= 1'b0;
    end
  end

  // Function defination
  integer             i;
  function automatic [DW_IN*SCALE-1:0] reverse;
    input [DW_IN*SCALE-1:0] d;
    begin
      for(i=0;i<SCALE;i=i+1)
        reverse[(i*DW_IN)+:DW_IN] = d[((SCALE-i-1)*DW_IN)+:DW_IN];
    end
  endfunction   

endmodule
