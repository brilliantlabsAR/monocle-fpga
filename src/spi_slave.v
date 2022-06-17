`timescale 1ns / 1ps

`include "defines.v"
`include "reg_addr_defines.v"
`define     SCLK_CLK_RATIO      24 //24:1
module spi_slave (
  // Register Interface
  clk,
  rst_n,
  wr_addr,
  wr_en,
  wr_data,
  rd_addr,
  rd_en,
  rd_data,
  clr_err,
  wr_burst_size, //in bytes
  rd_burst_size, //in bytes
  // SPI Slave Interface
  SCLK,
  MOSI,
  MISO,
  SS
);

  //IOs
  input  wire                       clk;
  input  wire                       rst_n;
  output wire [`REG_ADDR_WIDTH-1:0] wr_addr;
  output reg                        wr_en;
  output wire [`REG_SIZE-1:0]       wr_data;
  output wire [`REG_ADDR_WIDTH-1:0] rd_addr;
  output reg                        rd_en;
  input  wire [`REG_SIZE-1:0]       rd_data;
  input  wire                       clr_err;
  input  wire [`BURST_WIDTH-1:0]    wr_burst_size;
  input  wire [`BURST_WIDTH-1:0]    rd_burst_size;
  
  input  wire                       SCLK;
  input  wire                       MOSI;
  output wire                       MISO;
  input  wire                       SS;


  localparam [2:0]                  IDLE      = 3'b000;
  localparam [2:0]                  SPI_ADDR  = 3'b001; 
  localparam [2:0]                  ADDR_DONE = 3'b010;
  localparam [2:0]                  READ_ADDR = 3'b011;
  localparam [2:0]                  WRITE_REG = 3'b100;
  localparam [2:0]                  READ_REG  = 3'b101;
                                    
  localparam [2:0]                  SCLK_IDLE = 3'b000;
  localparam [2:0]                  SCLK_HIGH = 3'b001; 
  localparam [2:0]                  SCLK_LOW  = 3'b010;
  localparam [2:0]                  SCLK_POL_ERR = 3'b011;
  
  reg [2:0]                         rx_data_cnt/* synthesis syn_keep=1 */;
  reg [2:0]                         tx_data_cnt;
  reg [`DATA_LENGTH-1:0]            rx_shift_data;
  reg [`DATA_LENGTH-1:0]            rx_byte;
                                    
  reg                               rx_done;
  reg                               rx_done_d1;
  reg                               rx_done_d2;
  wire                              byte_rx_done_pulse;
  reg                               byte_rx_done_pulse_d1;

  reg                               tx_done;
  reg                               tx_done_d1;
  reg                               tx_done_d2;
  wire                              byte_tx_done_pulse;
  reg                               byte_tx_done_pulse_d1;
  
  reg [2:0]                         c_state;
  reg [2:0]                         n_state;
                                    
  reg                               rd_addr_done;
  reg                               cs_d1;
  reg                               cs_d2;
  reg                               sclk_d1;
  reg                               sclk_d2;
  reg                               sclk_d3;
  wire                              sclk_sync_fe;
  reg                               mosi_d1;
  reg                               mosi_d2;
  reg                               address_done;
  reg                               miso_i;
  wire                              burst_done;
  wire                              burst_done_d1;
  wire                              rd_wr_done;
  wire                              clr_rd_on;
  wire                              rd_done;
  wire                              wr_done;
  wire                              rd_wr_done_d1;
  reg  [15:0]                       burst_cntr;
  reg  [7:0]                        sclk_low_cntr;
  reg                               rd_on;
  wire                              sclk_stable;
  wire                              sclk_low_cntr_done;
  reg  [`REG_ADDR_WIDTH-1:0]        addr;
  wire [`BURST_WIDTH-1:0]           burst_size;
  reg [1:0]                         sclk_c_state;
  reg [1:0]                         sclk_n_state;
  reg [15:0]                        dbg_rd_burst_size_cntr;
  reg [15:0]                        dbg_lch_rd_burst_size_cntr;
  wire                              clr_dbg_cntr;
//  wire                              dbg_burst_size_err/* synthesis syn_keep=1 */;
//  wire                              dbg_burst_gt_252_err/* synthesis syn_keep=1 */;

  // User Clock Domain
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_d1 <= 1'b1;
      sclk_d2 <= 1'b1;
      mosi_d1 <= 1'b1;
      mosi_d2 <= 1'b1;
    end else begin
      sclk_d1 <= SCLK;
      sclk_d2 <= sclk_d1;
      sclk_d3 <= sclk_d2;
      mosi_d1 <= MOSI;
      mosi_d2 <= mosi_d1;
    end
  end
  
  assign sclk_sync_fe = (!sclk_d1) & sclk_d2;
  
  //*******************************************************************
  //* FSM For Generating Stable SCLK
  //*******************************************************************
  always @(posedge clk or posedge SS) begin
    if(SS) begin
      sclk_c_state <= SCLK_IDLE;
    end else begin
      sclk_c_state <= sclk_n_state;
    end
  end
  
  always @(*) begin
    case (sclk_c_state)
	  SCLK_IDLE  : begin
                     if (!cs_d2) begin
                       if (!sclk_d2) begin
                         sclk_n_state <= SCLK_POL_ERR;
                       end else begin
                         sclk_n_state <= SCLK_HIGH;
                       end
                     end else begin
                       sclk_n_state <= SCLK_IDLE;
                     end
	               end
      
      SCLK_HIGH  : begin
                     if (sclk_sync_fe) begin
                       sclk_n_state <= SCLK_LOW;
                     end else begin
                       sclk_n_state <= SCLK_HIGH;
                     end
	               end
      
      SCLK_LOW   : begin
                     if (sclk_low_cntr_done) begin
                       sclk_n_state <= SCLK_HIGH;
                     end else begin
                       sclk_n_state <= SCLK_LOW;
                     end
	               end

      SCLK_POL_ERR: begin
                     if (clr_err) begin // || dbg_burst_size_err || dbg_burst_gt_252_err) begin
                       sclk_n_state <= SCLK_IDLE;
                     end else begin
                       sclk_n_state <= SCLK_POL_ERR;
                     end
	               end
                   
      default    : sclk_n_state <= SCLK_IDLE;
    endcase
  end
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      sclk_low_cntr <= (`SCLK_CLK_RATIO/2)-1;
    end else if (sclk_c_state == SCLK_HIGH) begin //Load counter
      sclk_low_cntr <= (`SCLK_CLK_RATIO/2)-1;
    end else if (!sclk_low_cntr_done & sclk_c_state == SCLK_LOW) begin
      sclk_low_cntr <= sclk_low_cntr - 1;
    end
  end
  
  assign sclk_low_cntr_done = sclk_low_cntr == 0 ? 1'b1 : 1'b0;
  
  assign sclk_stable = sclk_c_state == SCLK_LOW ? 1'b0 : 1'b1;
  
  
//  always @(posedge sclk_stable or posedge SS)
//    if (SS)
//       dbg_cnt_p <= 'h0;
//    else if (!SS)
//       dbg_cnt_p <= dbg_cnt_p + 'h1;
//
//  always @(negedge sclk_stable or posedge SS)
//    if (SS)
//       dbg_cnt_n <= 'h0;
//    else if (!SS)
//       dbg_cnt_n <= dbg_cnt_n + 'h1;
      
  //*********************************************************************
  //* Receive data 
  //*********************************************************************
  //For Rx data, sample at posedge when `CLOCK_PHASE ^~ 'CLOCK_POLARITY is 1
  if (!(`CLOCK_PHASE ^ `CLOCK_POLARITY))
  begin
       always @(posedge sclk_stable or posedge SS)
         if (SS)
           rx_shift_data <= 'h0;
         else if (!SS)
           if (`SHIFT_DIRECTION)
              rx_shift_data <= {mosi_d2,rx_shift_data[`DATA_LENGTH-1:1]};
           else
              rx_shift_data <= {rx_shift_data[`DATA_LENGTH-2:0],mosi_d2};
  
       always @(posedge sclk_stable or posedge SS)
         if (SS)
            rx_data_cnt <= 'h0;
         else if (rx_data_cnt == `DATA_LENGTH-1)
            rx_data_cnt <= 'h0;
         else if (!SS)
            rx_data_cnt <= rx_data_cnt + 'h1;
  
       always @(posedge sclk_stable or posedge SS)
         if (SS)
           rx_done <= 1'b0;
         else if (rx_data_cnt == `DATA_LENGTH-1)
           rx_done <= 1'b1;
         else if(rx_data_cnt == 2)
           rx_done <= 1'b0;
  
  end
  else
  begin
      //For Rx data, sample at negedge when `CLOCK_PHASE ^~ 'CLOCK_POLARITY is 0
      always @(negedge sclk_stable or posedge SS)
         if (SS)
           rx_shift_data <= 'h0;
         else if (!SS)
           if (`SHIFT_DIRECTION)
             rx_shift_data <= {mosi_d2,rx_shift_data[`DATA_LENGTH-1:1]};
           else
             rx_shift_data <= {rx_shift_data[`DATA_LENGTH-2:0],mosi_d2};
  
       always @(negedge sclk_stable or posedge SS)
         if (SS)
            rx_data_cnt <= 'h0;
         else if (rx_data_cnt == `DATA_LENGTH - 1)
            rx_data_cnt <= 'h0;
         else if (!SS)
            rx_data_cnt <= rx_data_cnt + 'h1;
  
       always @(negedge sclk_stable or posedge SS)
         if (SS)
            rx_done <= 1'b0;
         else if (rx_data_cnt == `DATA_LENGTH - 1)
            rx_done <= 1'b1;
         else if(rx_data_cnt == 2)
            rx_done <= 1'b0;
  end
  
  
  //*******************************************************************
  //* Transmit data 
  //*******************************************************************
  //For Tx data, update at negedge when `CLOCK_PHASE =0,'CLOCK_POLARITY=0;
  //             update at posedge when `CLOCK_PHASE =0,'CLOCK_POLARITY=1;
  if (`CLOCK_PHASE ^ `CLOCK_POLARITY)
  begin
       always @(posedge sclk_stable or posedge SS)
         if (SS)
           miso_i <= 'h1;
         else
           miso_i <= `SHIFT_DIRECTION ? rd_data[tx_data_cnt] :
                                        rd_data[`DATA_LENGTH-tx_data_cnt-1];
  
       always @(posedge sclk_stable or posedge SS)
         if (SS)
           tx_data_cnt <= 'h0;
         else if (tx_data_cnt == `DATA_LENGTH - 1)
           tx_data_cnt <= 'h0;
         else if (!SS)
           tx_data_cnt <= tx_data_cnt + 'h1;
  
       always @(posedge sclk_stable or posedge SS)
         if (SS)
           tx_done <= 1'b0;
         else if (tx_data_cnt == `DATA_LENGTH - 1)
           tx_done <= 1'b1;
         else if(tx_data_cnt == 2)
           tx_done <= 1'b0;
       
       assign MISO = miso_i;
  end
  else
  //For Tx data, update at negedge when `CLOCK_PHASE = 1,'CLOCK_POLARITY == 1;
  //             update at posedge when `CLOCK_PHASE = 1,'CLOCK_POLARITY == 0; 
  begin
       always @(negedge sclk_stable or posedge SS)
         if (SS)
           miso_i <= 'h1;
         else
           miso_i <= `SHIFT_DIRECTION ? rd_data[tx_data_cnt] :
                                        rd_data[`DATA_LENGTH-tx_data_cnt-1];
  
       always @(negedge sclk_stable or posedge SS)
         if (SS)
           tx_data_cnt <= 'h0;
         else if (tx_data_cnt == `DATA_LENGTH - 1)
           tx_data_cnt <= 'h0;
         else if (!SS)
           tx_data_cnt <= tx_data_cnt + 'h1;
  
       always @(negedge sclk_stable or posedge SS)
         if (SS)
           tx_done <= 1'b0;
         else if (tx_data_cnt == `DATA_LENGTH - 1)
           tx_done <= 1'b1;
         else if(tx_data_cnt == 2)
           tx_done <= 1'b0;
       
       assign MISO = !SS ? miso_i : 1'bz;
  end



  // User Clock Domain
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs_d1 <= 1'b1;
      cs_d2 <= 1'b1;
    end else begin
      cs_d1 <= SS;
      cs_d2 <= cs_d1;
    end
  end
  
  // Cross from SPI Clock Domain to User clock domain
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_done_d1 <= 1'b0;
      rx_done_d2 <= 1'b0;
      
      tx_done_d1 <= 1'b0;
      tx_done_d2 <= 1'b0;
    end else begin
      rx_done_d1 <= rx_done;
      rx_done_d2 <= rx_done_d1;
      
      tx_done_d1 <= tx_done;
      tx_done_d2 <= tx_done_d1;
    end
  end
  
  assign byte_rx_done_pulse = (rx_done_d2 == 1'b0 & rx_done_d1 == 1'b1) ? 1'b1 : 1'b0;
  assign byte_tx_done_pulse = (tx_done_d2 == 1'b0 & tx_done_d1 == 1'b1) ? 1'b1 : 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_rx_done_pulse_d1 <= 1'b0;
      byte_tx_done_pulse_d1 <= 1'b0;
    end else begin
      byte_rx_done_pulse_d1 <= byte_rx_done_pulse;
      byte_tx_done_pulse_d1 <= byte_tx_done_pulse;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_byte <= 8'h00;
    end else if (byte_rx_done_pulse) begin
      rx_byte <= rx_shift_data;
    end
  end

  
  //*******************************************************************
  //* Register Control FSM
  //*******************************************************************
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      c_state <= IDLE;
    end else begin
      c_state <= n_state;
    end
  end

  always @(*) begin
    //Default signal values
    //n_state <= c_state;
    
    case (c_state)
	  IDLE       : begin
                     if (!cs_d2) begin
                       if (address_done) begin
                         n_state <= ADDR_DONE;
                       end else begin
                         n_state <= SPI_ADDR;
                       end
                     end else begin
                       n_state <= IDLE;
                     end
	               end
      
      SPI_ADDR   : begin
                     if (byte_rx_done_pulse_d1) begin
                       n_state <= ADDR_DONE;
                     end else begin
                       n_state <= SPI_ADDR;
                     end
	               end
      
      ADDR_DONE  : begin
                     if (!rd_on | (rd_on & rx_byte == `READ_ON)) begin
                       n_state <= WRITE_REG;
                     end else if (rx_byte == 8'h81) begin //rd_on
                       if (rd_addr_done) begin
                         n_state <= READ_REG;
                       end else begin
                         n_state <= READ_ADDR;
                       end
                     end else begin // should not come here
                       n_state <= ADDR_DONE;
                     end
	               end
      
      READ_ADDR  : begin
                     if (byte_rx_done_pulse_d1) begin
                       n_state <= IDLE;
                     end else begin
                       n_state <= READ_ADDR;
                     end
	               end
      
      WRITE_REG  : begin
                     if (rd_wr_done_d1) begin
                       n_state <= IDLE;
                     end else begin
                       n_state <= WRITE_REG;
                     end
	               end
      
      READ_REG   : begin
                     if (rd_wr_done_d1) begin
                       n_state <= IDLE;
                     end else begin
                       n_state <= READ_REG;
                     end
	               end
      
      default    : n_state <= IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      addr <= 8'h00;
    end else if ((c_state == SPI_ADDR | c_state == READ_ADDR) & byte_rx_done_pulse_d1) begin
      addr <= rx_byte;
    end
  end
  
  assign wr_addr = addr;
  assign rd_addr = addr;
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      rd_addr_done <= 1'b0;
    end else if (c_state == READ_ADDR) begin
      rd_addr_done <= 1'b1;
    end else if (c_state == READ_REG) begin
      rd_addr_done <= 1'b0;
    end
  end
  
  assign clr_rd_on = rd_wr_done_d1 & c_state == READ_REG ? 1'b1 : 1'b0;
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n | clr_rd_on) begin
      rd_on <= 1'b0;
    end else if (wr_en & wr_addr == `READ_ON & wr_data[0]) begin
      rd_on <= 1'b1;
    end
  end
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n | cs_d2) begin
      address_done <= 1'b0;
    end else if (c_state == ADDR_DONE) begin
      address_done <= 1'b1;
    end
  end
  
//  always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//      wr_addr <= 8'h00;
//    end else if (c_state == SPI_ADDR & byte_rx_done_pulse_d1) begin
//      wr_addr <= rx_byte;
//    end
//  end
//  
//  always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//      wr_en <= 1'b0;
//    end else if (c_state == WRITE_REG & byte_rx_done_pulse_d1) begin
//      wr_en <= 1'b1;
//    end else begin
//      wr_en <= 1'b0;
//    end
//  end
  
  assign rd_done = (c_state ==  READ_REG & byte_tx_done_pulse_d1) ? 1'b1 : 1'b0;
  assign wr_done = (c_state ==  WRITE_REG & byte_rx_done_pulse_d1) ? 1'b1 : 1'b0;
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      wr_en <= 1'b0;
      rd_en <= 1'b0;
    end else begin
      wr_en <= wr_done;
      rd_en <= rd_done;
    end
  end
  
  //*******************************************************************
  //* Burst Access
  //*******************************************************************
  assign burst_size = (addr == `BURST_WR_DATA) ? wr_burst_size :
                      (addr == `BURST_RD_DATA) ? rd_burst_size :
                      1;
  
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      burst_cntr <= 16'h0;
    end else if (c_state == ADDR_DONE) begin //Load counter
      burst_cntr <= burst_size;
    end else if (!burst_done & (wr_done | rd_done)) begin
      burst_cntr <= burst_cntr - 1;
    end
  end
  
  assign burst_done = burst_cntr == 0 ? 1'b1 : 1'b0;
  
//  //****Only for debug
//  always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//      dbg_rd_burst_size_cntr <= 16'h0;
//    end else if (c_state ==  READ_REG && rd_addr == 8'h0B) begin
//      if (byte_tx_done_pulse_d1) begin
//        dbg_rd_burst_size_cntr <= dbg_rd_burst_size_cntr + 1;
//      end
//    end else begin
//      dbg_rd_burst_size_cntr <= 16'h0;
//    end
//  end
//  
//  // Latch read burst count
//  always @(posedge clk or negedge rst_n) begin
//    if(!rst_n) begin
//      dbg_lch_rd_burst_size_cntr <= 16'h0;
//    end else if (clr_dbg_cntr) begin
//      dbg_lch_rd_burst_size_cntr <= 16'h0;
//    end else if (rd_wr_done && !rd_wr_done_d1) begin
//      dbg_lch_rd_burst_size_cntr <= dbg_rd_burst_size_cntr;
//    end
//  end
//  
//  assign clr_dbg_cntr = ((c_state == ADDR_DONE) || (c_state == SPI_ADDR)) ? 1'b1 : 1'b0;
//  
//  assign dbg_burst_size_err = (burst_size > 2) && (c_state == IDLE) && (dbg_lch_rd_burst_size_cntr != burst_size) && (dbg_lch_rd_burst_size_cntr != 0) ? 1'b1 : 1'b0;
//  assign dbg_burst_gt_252_err = dbg_rd_burst_size_cntr == 253 ? 1'b1 : 1'b0;
  //****
  
/*  
  // For timing only
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      burst_done_d1 <= 1'b0;
    end else begin
      burst_done_d1 <= burst_done;
    end
  end
*/  
  assign burst_done_d1 = burst_done;
  assign rd_wr_done = cs_d2 & burst_done_d1 ? 1'b1 : 1'b0;
/*  
  // For timing only
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      rd_wr_done_d1 <= 1'b0;
    end else begin
      rd_wr_done_d1 <= rd_wr_done;
    end
  end
*/  
  assign rd_wr_done_d1 = rd_wr_done;

  assign wr_data = rx_byte;
  
endmodule

