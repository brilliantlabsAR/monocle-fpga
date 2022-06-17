module chk_sum_16 (
  rst,
  clk,
  chk_sum_rst,
  enable,
  data,
  chk_sum
);

  input  wire             rst;
  input  wire             clk;
  input  wire             chk_sum_rst;
  input  wire             enable;
  input  wire [15:0]      data;
  output wire [15:0]      chk_sum;
  
  wire [19:0]             data_1c_sum;
  wire [3:0]              data_1c_sum_carry;
  wire [19:0]             data_1c_sum16_i;
  wire [3:0]              data_1c_sum16_carry_i;
  wire [15:0]             data_1c_sum16;
  reg  [15:0]             result_reg;

  assign data_1c_sum = {4'h0, result_reg} + {4'h0, {data[15:8], data[7:0]}};
  
  assign data_1c_sum_carry = data_1c_sum[19:16];
  
  assign data_1c_sum16_i = {4'h0, data_1c_sum[15:0]} + {16'h0, data_1c_sum_carry};
  
  assign data_1c_sum16_carry_i = data_1c_sum16_i[19:16];

  assign data_1c_sum16 = data_1c_sum16_i[15:0] + {12'h0, data_1c_sum16_carry_i};
  
  always@(posedge clk) begin
    if (rst | chk_sum_rst) begin
      result_reg <= 16'h0;
    end else if (enable) begin
      result_reg <= data_1c_sum16;
    end
  end
  
  assign chk_sum = result_reg;
  
endmodule 