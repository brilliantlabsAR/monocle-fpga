module rst_sync (
  sys_clk,
  reg_clk,
  cam_clk,
  disp_clk,
  rst,
  sys_rst,
  reg_rst,
  cam_rst,
  disp_rst
);

  localparam SYNC_STAGES          = 2;

  input                             sys_clk;
  input                             reg_clk;
  input                             cam_clk;
  input                             disp_clk;
                                    
  input                             rst;
                                    
  output                            sys_rst;
  output                            reg_rst;
  output                            cam_rst;
  output                            disp_rst;
  
  
  reg  [SYNC_STAGES-1:0]            sys_rst_sync;
  reg  [SYNC_STAGES-1:0]            reg_rst_sync;
  reg  [SYNC_STAGES-1:0]            cam_rst_sync;
  reg  [SYNC_STAGES-1:0]            disp_rst_sync;

  //================================================
  // System Clock
  //================================================
  always@(posedge sys_clk) begin
    if (rst) begin
      sys_rst_sync <= {SYNC_STAGES{1'b1}};
    end else begin
      sys_rst_sync <= {sys_rst_sync[SYNC_STAGES-2:0],1'b0};
    end
  end
  
  assign sys_rst = sys_rst_sync[SYNC_STAGES-1];

  //================================================
  // Register Clock
  //================================================
  always@(posedge reg_clk) begin
    if (rst) begin
      reg_rst_sync <= {SYNC_STAGES{1'b1}};
    end else begin
      reg_rst_sync <= {reg_rst_sync[SYNC_STAGES-2:0],1'b0};
    end
  end
  
  assign reg_rst = reg_rst_sync[SYNC_STAGES-1];

  //================================================
  // Camera Clock
  //================================================
  always@(posedge cam_clk) begin
    if (rst) begin
      cam_rst_sync <= {SYNC_STAGES{1'b1}};
    end else begin
      cam_rst_sync <= {cam_rst_sync[SYNC_STAGES-2:0],1'b0};
    end
  end
  
  assign cam_rst = cam_rst_sync[SYNC_STAGES-1];
  
  //================================================
  // Display Clock
  //================================================
  always@(posedge disp_clk) begin
    if (rst) begin
      disp_rst_sync <= {SYNC_STAGES{1'b1}};
    end else begin
      disp_rst_sync <= {disp_rst_sync[SYNC_STAGES-2:0],1'b0};
    end
  end
  
  assign disp_rst = disp_rst_sync[SYNC_STAGES-1];
  
endmodule 