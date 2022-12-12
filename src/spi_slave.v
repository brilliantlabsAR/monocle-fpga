module spi_slave #(
   parameter SPI_MODE = 3,
   parameter FIRST_BIT = 7
) (
   input reset,
   input clk,
   input sclk,
   input mosi,
   output miso,
   input ssn,
   output api_start,
   output api_strobe,
   output api_next,
   output [7:0] api_din,
   input [7:0] api_dout
 );


   reg 	       start;
   reg [2:0]   bit_cnt;
   reg [2:0]   sclk_sync;
   reg [1:0]   mosi_sync;
   reg [7:0]   datain;
   reg [7:0]   dataout;

   always @(posedge clk)
     sclk_sync <= {sclk_sync[1:0], sclk};   

   always @(posedge clk)
     mosi_sync <= {mosi_sync[0], mosi};

   wire        leading_edge, trailing_edge, sample, shiftout, rx_vld;
   reg 	       sample_d;

   generate if (SPI_MODE==0)
     begin
	assign leading_edge = ~sclk_sync[2] & sclk_sync[1];
	assign trailing_edge = sclk_sync[2] & ~sclk_sync[1];
	assign sample = leading_edge;
	assign shiftout = trailing_edge;
     end
   else if (SPI_MODE==1)
     begin
	assign leading_edge = ~sclk_sync[2] & sclk_sync[1];
	assign trailing_edge = sclk_sync[2] & ~sclk_sync[1];

	assign sample = trailing_edge;

	reg tx_en;
	
	always @(posedge clk)
	  if (reset | ssn)
	    tx_en <= 0;
	  else if (leading_edge)
	    tx_en <= 1'b1;

	assign shiftout = leading_edge & tx_en;
     end
   else if (SPI_MODE==2)
     begin
	assign leading_edge = sclk_sync[2] & ~sclk_sync[1];
	assign trailing_edge =  ~sclk_sync[2] & sclk_sync[1];
	assign sample = leading_edge;
	assign shiftout = trailing_edge;
     end
   else if (SPI_MODE==3)
     begin
	assign leading_edge = sclk_sync[2] & ~sclk_sync[1];
	assign trailing_edge = ~sclk_sync[2] & sclk_sync[1];

	assign sample = trailing_edge;

	reg tx_en;
	
	always @(posedge clk)
	  if (reset | ssn)
	    tx_en <= 0;
	  else if (leading_edge)
	    tx_en <= 1'b1;

	assign shiftout = leading_edge & tx_en;
     end
   endgenerate
/*
   always @(posedge clk)
     if (reset | ssn)
       start <= 1'b1;
     else if ()
       start <= 1'b0;
*/
   always @(posedge clk)
     if (reset | ssn)
       bit_cnt <= 0;
   else if (leading_edge)
       bit_cnt <= bit_cnt + 1;

   reg 	    last_bit;
   wire     bit0, bit7;

   assign bit0 = (bit_cnt == 0);
   assign bit7 = (bit_cnt == 7);

   always @(posedge clk)
     sample_d <= sample;

   // In SPI modes 0 & 2, sample == leading_edge, so last_bit comes a
   // cycle after the last sample pulse.

   always @(posedge clk)
     if (reset | ssn)
       last_bit <= 1'b0;
     else if (leading_edge)
       last_bit <= bit7;

   generate if(FIRST_BIT==7) begin
      always @(posedge clk)
	if (sample)
	  datain <= {datain[6:0], mosi_sync[1]};
   end else begin
      always @(posedge clk)
	if (sample)
	  datain <= {mosi_sync[1], datain[7:1]};
   end
   endgenerate

   assign rx_vld = last_bit & sample_d;

   // Tx data is capture at leading edge.  In SPI modes 0 & 2, the
   // first bit has already been captured, so the api_dout input must
   // be stable prior to the transaction start.
   
   generate if(FIRST_BIT==7) begin
      always @(posedge clk)
	if (!ssn) begin
	   if (bit0 & leading_edge)
	     dataout <= api_dout;
	   else if (shiftout)
	     dataout <= {dataout[6:0], 1'b0};
	end
   end else begin
      always @(posedge clk)
	if (!ssn) begin
	   if (bit0 & leading_edge)
	     dataout <= api_dout;
	   else if (shiftout)
	     dataout <= {1'b0, dataout[7:1]};
	end
   end
   endgenerate

   always @(posedge clk)
     if (reset | ssn)
       start <= 1'b1;
     else if (rx_vld)
       start <= 1'b0;

   assign miso = dataout[FIRST_BIT];
   assign api_din = datain;

   // Don't strobe during start transaction b/c the api still
   // thinks we are accessing the previous dev/reg until it gets
   // the start which comes at the end of the transaction.
   assign api_strobe = bit0 & leading_edge & ~start;
   assign api_next = rx_vld;
   assign api_start = rx_vld & start;

endmodule