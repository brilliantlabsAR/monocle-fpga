`default_nettype none

module clk_div (
  clk, 
  rst,
  en,
  clk_out
);

  // Parameter Declaration
  parameter DIV_FACTOR            = 10; //Actual division will be DIV_FACTOR x 2
  
  // IOs Declaration
  input  wire                       clk;
  input  wire                       rst;
  input  wire                       en;
  output wire                       clk_out;
    
  // Local Parameter
  localparam CNT_WIDTH            = $clog2(DIV_FACTOR);
  
  // Reg & Wire Declaration
  reg  [CNT_WIDTH-1:0]              cnt_div;
  wire                              cnt_done;
  reg                               en_d1;
  reg                               en_sync;
  reg                               clk_reg;

  // Synchronize Camera control bit
  always@(posedge clk) begin
    en_d1   <= en;
    en_sync <= en_d1;
  end

  always @(posedge clk or posedge rst) begin
    if(rst) begin
      cnt_div <= {CNT_WIDTH{1'b0}};
    end else if(en_sync) begin
      if(cnt_done) begin
        cnt_div <= {CNT_WIDTH{1'b0}};
      end else begin
        cnt_div <= cnt_div + 1;
      end
    end
  end
  
  assign cnt_done = (cnt_div == DIV_FACTOR-1) ? 1'b1 : 1'b0;
  
  always @(posedge clk or posedge rst) begin
    if(rst) begin
      clk_reg <= 1'b0;
    end else if(en_sync & cnt_done) begin
      clk_reg <= ~clk_reg;
    end
  end
  
//  ODDR #(
//    .INIT      (1'b0    ),
//    .TXCLK_POL (1'b0    )
//  ) i_ODDR (
//    .Q0        (clk_out ),
//    .Q1        (        ),
//    .D0        (1'b0    ),
//    .D1        (1'b1    ),
//    .TX        (1'b0    ),
//    .CLK       (clk_reg )
//  );
  
  assign clk_out = clk_reg;
  
endmodule // clk_div 

`default_nettype wire