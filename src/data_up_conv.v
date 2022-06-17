module data_up_conv (
  clk,
  rst,
  //Slave Interface
  vld_i,
  data_i,
  //Master Interface
  vld_o,
  data_o
);

  // Parameters
  
  // IOs
  input  wire                       rst;
  input  wire                       clk;
  input  wire                       vld_i;
  input  wire [7:0]                 data_i;
  output wire                       vld_o;
  output wire [31:0]                data_o;
  
  reg  [31:0]                       data_shreg;
  reg  [1:0]                        data_cntr;
  wire                              cnt_done;
  
  
  always @(posedge clk) begin
    if (rst) begin
      data_cntr <= 2'b0;
    end else if (vld_i) begin
      if (cnt_done) begin
        data_cntr <= 1'b0;
      end else begin
        data_cntr <= data_cntr + 2'b1;
      end
    end
  end  

  assign cnt_done = data_cntr == 2'b11 ? 1'b1 : 1'b0;
  
  assign vld_o = vld_i & cnt_done;
  
  always @(posedge clk) begin
    if (rst) begin
      data_shreg <= 32'h0;
    end else if (vld_i) begin
      data_shreg[data_cntr*8+:8] <= data_i;
    end
  end 
  
  assign data_o = {data_shreg[23:0], data_i};
  
endmodule
