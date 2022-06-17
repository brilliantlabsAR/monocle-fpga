`default_nettype none

`include "defines.v"
module stat (
  clk,
  rst,
  vsync,
  href,
  frm_per_sec,
  total_frm,
  total_byte,
  lines_per_frm,
  bytes_per_line,
  bytes_per_frm,
  frm_lt_512k_err
); 
  
  // Parameter Declaration
  parameter CLKFREQ_HZ            = 24000000; //24Mhz
  parameter STAT_FOR_DISP         = 1'b0;
    
  // IOs Declaration      
  input  wire                        clk;
  input  wire                        rst;
  input  wire                        vsync;
  input  wire                        href;
  output reg  [7:0]                  frm_per_sec;
  output wire [`STAT_CNTR_WIDTH-1:0] total_frm;
  output reg  [`STAT_CNTR_WIDTH-1:0] total_byte;
  output reg  [10:0]                 lines_per_frm;
  output reg  [11:0]                 bytes_per_line;
  output reg  [18:0]                 bytes_per_frm;
  output reg                         frm_lt_512k_err;  
  
  // Local Parameter
  
  // Reg & Wire Declaration
  reg  [`STAT_CNTR_WIDTH-1:0]       total_frm_cntr;
  reg  [10:0]                       line_cntr;
  reg  [11:0]                       byte_cntr;
  reg  [18:0]                       frm_byte_cntr;
  reg  [`STAT_CNTR_WIDTH-1:0]       cur_val;
  reg  [`STAT_CNTR_WIDTH-1:0]       prev_val;
  wire [7:0]                        diff_val;
  wire                              pulse_1sec;  
  reg                               vsync_d1;
  reg                               href_d1;
  wire                              vsync_re;  
  wire                              vsync_fe;  
  wire                              href_re;  
  wire                              href_fe;  
  


  pulsar #(
    .CLKFREQ_HZ      (CLKFREQ_HZ   )
  ) i_pulsar (
    .clk             (clk          ),
    .rst             (rst          ),
    .pulse_out       (pulse_1sec   )
  );
  
  always@(posedge clk) begin
    vsync_d1 <= vsync;
    href_d1  <= href;
  end
  
  assign vsync_re = (!vsync_d1) & vsync;
  assign vsync_fe = vsync_d1 & (!vsync);
  
  assign href_re = (!href_d1) & href;
  assign href_fe = href_d1 & (!href);
  
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      total_frm_cntr <= 'd0;
    end else if(vsync_re) begin
      total_frm_cntr <= total_frm_cntr + 1'b1;
    end
  end

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      cur_val  <= 0;
      prev_val <= 0;
    end else if(pulse_1sec) begin
      cur_val  <= total_frm_cntr;
      prev_val <= cur_val;
    end
  end
  
  assign diff_val = cur_val - prev_val;
  
  always@(posedge clk or posedge rst) begin
    if (rst) begin
      frm_per_sec <= 'd0;
    end else begin
      frm_per_sec <= diff_val;
    end
  end
  
  assign total_frm = total_frm_cntr;
  
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      total_byte <= 0;
    end else if(href) begin
      total_byte <= total_byte + (STAT_FOR_DISP ? 'd2 : 'd1);
    end
  end
  
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      line_cntr <= 'd0;
    end else if (href_re) begin
      line_cntr <= line_cntr + 1'b1;
    end else if (vsync_re) begin
      line_cntr <= 'd0;
    end
  end

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      lines_per_frm <= 'd0;
    end else if (vsync_re) begin
      lines_per_frm <= line_cntr;
    end
  end
  
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      byte_cntr <= 12'd0;
    end else if(href) begin
      byte_cntr <= byte_cntr + (STAT_FOR_DISP ? 'd2 : 'd1);
    end else begin
      byte_cntr <= 12'd0;
    end
  end

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      bytes_per_line <= 12'd0;
    end else if (href_fe) begin
      bytes_per_line <= byte_cntr;
    end
  end

  always @(posedge clk or posedge rst) begin
    if (rst | vsync_re) begin
      frm_byte_cntr <= 19'd0;
    end else if(href) begin
      frm_byte_cntr <= frm_byte_cntr + (STAT_FOR_DISP ? 'd2 : 'd1);
    end
  end
  
  // Frame Length
  always@(posedge clk or posedge rst) begin
    if(rst)
      bytes_per_frm <= 19'd0;
    else if(vsync_fe)
      bytes_per_frm <= frm_byte_cntr;
  end
  
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      frm_lt_512k_err <= 1'b0;
    end else if(vsync_re && (frm_byte_cntr != `FRAME_LENGTH) && (frm_byte_cntr != 0)) begin
      frm_lt_512k_err <= 1'b1;
      $display ("ERROR: Frame Length <512000 from camera..!");
      //$stop;
    end else begin
      frm_lt_512k_err <= 1'b0;
    end      
  end
  
endmodule // stat 

`default_nettype wire