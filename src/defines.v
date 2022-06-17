`define MK11

//`define EN_DEBUG_CNTR

`define REVISION_MINOR                       8'd2
`define REVISION_MAJOR                       8'd1


//`define EN_CAM_CROSS
//===================================================================
//*** Disable external camera, enable FPGA camera frame generation
//===================================================================
//`define DISABLE_CAMERA
//*Background
//If not defined any of following, then OLED will be full white (WHITE_OLED) by default
//`define BAR_PATTERN
//`define WHITE_OLED
`define BLACK_OLED
//`define BLUE_OLED

//*Foreground -CROSS
//`define YELLOW_CROSS
`define WHITE_CROSS
//`define RED_CROSS
//`define BLUE_CROSS
//`define GREEN_CROSS

`define CROSS_LINE_NUM                       700
 // Pixel horizontal 641
`define CROSS_PIX_START                      884
`define CROSS_PIX_END                        887

//For GAO Test
//**NOTE:- Checksum = 0x37DF
//`define GAO_BAR_PATTERN
//===================================================================




//`define BURST_RDWR_TEST

//*** Single Frame Capture and Replay continuously
//`define SINGLE_FRAME_REPLAY

//*** Make simulation fast for capture
//`define FAST_CAPT_SIM

//`define EN_AUDIO_TEST_PAT

// Camera
`define CAM_DSIZE                            8
`define FRAME_LENGTH                         512000
`define HIGH_RES_FL                          5971968
//Actual frame length width 23, 1bit extra to byte align 
`define FL_WIDTH                             24
`define MAX_FRM_ROW                          400
`define MAX_FRM_COL                          1280
  
// Zoom
//2x
`define START_ROW_2x                         100
`define START_COL_2x                         160*2
`define END_ROW_2x                           300
`define END_COL_2x                           480*2
`define VALID_COL_BYTE_2x                    320*2
//4x
`define START_ROW_4x                         150
`define START_COL_4x                         240*2
`define END_ROW_4x                           250
`define END_COL_4x                           400*2
`define VALID_COL_BYTE_4x                    160*2
//8x
`define START_ROW_8x                         175
`define START_COL_8x                         280*2
`define END_ROW_8x                           225
`define END_COL_8x                           360*2
`define VALID_COL_BYTE_8x                    80*2

//Mic
//`define EN_MIC_IF
`define PCM_DSIZE                            16

//Display                                    
`define DISP_DSIZE                           16
                                             
//Memory Controller                          
// Burst length should be always in integer multiple of frame length
// i.e. (FRAME_LENGTH/MEM_WR_RD_BL) = Integer Value
// NOTE: afifo_fwft_36x1024 Almost Full/Empty threshold should be same as MEM_WR_RD_BL
//`define BURST_LEN                            32
`define MEM_WR_BL                            32
`define MEM_RD_BL                            32
`define TOTAL_BUF                            32
//`define TOTAL_A_BUF_SIZE                     524288
//`define TOTAL_BUF                            7
`define MAX_FRM_PER_BUF                      4
`define MAX_TOTAL_FRM                        512

// Frame Length with 1/4 compression ratio
`define AVG_FRM_LEN                          FRAME_LENGTH/4

// 63 frames / 15.271fps = 4.125467 seconds
// 4.125467 s * 48,000 B/s = EVEN_UP(1,98,022.42 Bytes) + 120 bytes (to make in multiple of burst)
//`define REQ_A_BUF_SIZE                       198024
`define REQ_A_BUF_SIZE                       198144

//ONLY for SIM
//***`define REQ_A_BUF_SIZE                       256
           
//===================================================================
//RB Shift
//===================================================================
// 1 based line counts
`define R_START_LINE                         4
`define G_START_LINE                         3
`define B_START_LINE                         0
`define R_END_LINE                           400
`define G_END_LINE                           399
`define B_END_LINE                           396
`define END_FRM                              400
//===================================================================

//System                                     
`define DSIZE                                36
`define DSIZE_SOF_BIT                        32
`define DSIZE_EOF_BIT                        33
                                             
  // SPI                                     
`define SHIFT_DIRECTION                      1   // 0: MSB->LSB , 1: LSB -> MSB
`define CLOCK_PHASE                          1   
`define CLOCK_POLARITY                       1
`define DATA_LENGTH                          8
                                             
`define REG_ADDR_WIDTH                       8
`define REG_SIZE                             8

`define BURST_WIDTH                          16 //Max 64kB

`define STAT_CNTR_WIDTH                      64

`define TIED_TO_VCC                          1'b1
`define TIED_TO_GND                          1'b0

