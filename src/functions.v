  // YCbCr2RGB
  function [23:0] ycbcr422torgb888;
    input [7:0] y, cb, cr;
    reg   [7:0] r, g, b, cb_minus_128, cr_minus_128;
    begin
      // Formula -From https://en.wikipedia.org/wiki/YUV
      // Subtract 128 offset from Cb and Cr to overcome overflow
      cb_minus_128 = cb - 128;
      cr_minus_128 = cr - 128;
      
      //Integer operation of ITU-R standard for YCbCr(8 bits per channel) to RGB888
      r = y+cr_minus_128+(cr_minus_128>>2)+(cr_minus_128>>3)+(cr_minus_128>>5);
      g = y-((cb_minus_128>>2)+(cb_minus_128>>4)+(cb_minus_128>>5))-((cr_minus_128>>1)+(cr_minus_128>>3)+(cr_minus_128>>4)+(cr_minus_128>>5));
      b = y+cb_minus_128+(cb_minus_128>>1)+(cb_minus_128>>2)+(cb_minus_128>>6);
      
      ycbcr422torgb888 = {r,g,b};
    end
  endfunction
  
  
  // RGB2YCbCr
  function [23:0] rgb888toycbcr422;
    input [7:0] r, g, b;
    reg   [15:0] y, cb, cr;
    begin
      // Formula -From https://sistenix.com/rgb2ycbcr.html
      y  = 16'd16  + (((r<<6)+(r<<1)+(g<<7)+g+(b<<4)+(b<<3)+b)>>8);
      cb = 16'd128 + ((-((r<<5)+(r<<2)+(r<<1))-((g<<6)+(g<<3)+(g<<1))+(b<<7)-(b<<4))>>8);
      cr = 16'd128 + (((r<<7)-(r<<4)-((g<<6)+(g<<5)-(g<<1))-((b<<4)+(b<<1)))>>8);
      
      rgb888toycbcr422 = {y[7:0], cb[7:0], cr[7:0]};
    end
  endfunction