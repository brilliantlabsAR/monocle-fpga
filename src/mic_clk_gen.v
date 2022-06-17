`default_nettype none

module mic_clk_gen (
  clk_board, 
  rst,
  en,
  clk_2_4mhz,
  clk_1_2mhz
);

  // Parameter Declaration
  parameter DIV_FACTOR            = 10; //Actual division will be DIV_FACTOR x2, Ex DIV_FACTOR=10 will be /20.
  
  // IOs Declaration
  input  wire                       clk_board;
  input  wire                       rst;
  input  wire                       en;
  output reg                        clk_2_4mhz;
  output reg                        clk_1_2mhz;
    
  // Local Parameter
  localparam CNT_WIDTH            = $clog2(DIV_FACTOR);
  
  // Reg & Wire Declaration
  reg  [CNT_WIDTH-1:0]              cnt_div;
  wire                              cnt_done;
  reg                               en_d1;
  reg                               en_sync;
  reg                               clk_1_2mhz_sync;
  reg                               cnt_done_d1;

  // Synchronize Camera control bit
  always@(posedge clk_board) begin
    en_d1   <= en;
    en_sync <= en_d1;
	cnt_done_d1 <= cnt_done;
  end

  always @(posedge clk_board or posedge rst) begin
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
  
  always @(posedge clk_board or posedge rst) begin
    if(rst) begin
      clk_2_4mhz <= 1'b0;
    end else if(en_sync & cnt_done) begin
      clk_2_4mhz <= ~clk_2_4mhz;
    end
  end
  
  //always @(posedge clk_2_4mhz or posedge rst) begin
  //  if(rst) begin
  //    clk_1_2mhz <= 1'b0;
  //  end else if(en_sync) begin
  //    clk_1_2mhz <= ~clk_1_2mhz;
  //  end
  //end
  
  // 1 cycle off than clk_2_4mhz
  always @(posedge clk_board or posedge rst) begin
    if(rst) begin
      clk_1_2mhz <= 1'b0;
    end else if(en_sync && clk_2_4mhz && cnt_done_d1) begin
      clk_1_2mhz <= ~clk_1_2mhz;
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
  
endmodule // mic_clk_gen 

`default_nettype wire