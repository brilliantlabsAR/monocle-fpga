`default_nettype none

module pulsar (
  clk,
  rst,
  pulse_out
); 
  
  // Parameter Declaration
  parameter CLKFREQ_HZ            = 24000000; //24Mhz
  parameter CNTR_WIDTH            = $clog2(CLKFREQ_HZ);
  
  // IOs Declaration      
  input  wire                       clk;
  input  wire                       rst;
  output reg                        pulse_out;
  
  // Local Parameter
  
  // Reg & Wire Declaration
  reg  [CNTR_WIDTH-1:0]             pulse_cntr;
  wire                              pulse_gen;  
  
  
  // Pulse Counter
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      pulse_cntr <= {CNTR_WIDTH{1'b0}};
    end else begin
      if (pulse_out) begin
        pulse_cntr <= {CNTR_WIDTH{1'b0}};
      end else begin
        pulse_cntr <= pulse_cntr + 1;
      end
    end
  end
  
  // 1 Sec pulse
  assign pulse_gen = pulse_cntr == CLKFREQ_HZ ? 1'b1 : 1'b0;
  
  // Pipeline the pulse_gen
  always @(posedge clk) begin
    pulse_out <= pulse_gen;
  end

endmodule // pulsar 

`default_nettype wire