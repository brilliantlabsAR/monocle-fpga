/********************************************************************/
/*MIT License

Copyright (c) 2020 Berin Martini

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
/********************************************************************/

/*
Adds a register to a valid-ready stream: can be useful for interfacing to non
stream type components and helping with timing closure.
*/

`default_nettype none

module stream_reg #(parameter DATA_WIDTH = 32) (
  input  wire                  clk   ,
  input  wire                  rst   ,
  input  wire [DATA_WIDTH-1:0] up_bus,
  input  wire                  up_val,
  output reg                   up_rdy,
  output reg  [DATA_WIDTH-1:0] dn_bus,
  output reg                   dn_val,
  input  wire                  dn_rdy
);

    reg  [DATA_WIDTH-1:0]   skid_bus;
    reg                     skid_val;

    wire                    dn_active;
    wire                    dn_val_i;
    wire [DATA_WIDTH-1:0]   dn_bus_i;


    // skid_bus always reflects downstream data's last cycle
    always @(posedge clk)
        skid_bus <= dn_bus_i;


    // skid_val remembers if there is valid data in the skid register until
    // it's consumed by the downstream
    always @(posedge clk)
        if (rst)    skid_val <= 1'b0;
        else        skid_val <= dn_val_i & ~dn_active;


    // down stream mux: if up_rdy not active, use last cycle's data and valid
    assign dn_bus_i = up_rdy ? up_bus : skid_bus;

    assign dn_val_i = up_rdy ? up_val : skid_val;


    // when down stream is ready or up stream has valid data, set upstream
    // ready to high if the modules 'down' pipeline is not stalled
    always @(posedge clk)
        if      (rst)               up_rdy <= 1'b0;
        else if (dn_rdy | up_val)   up_rdy <= dn_active;


    always @(posedge clk)
        if      (rst)       dn_val <= 1'b0;
        else if (dn_active) dn_val <= dn_val_i;


    always @(posedge clk)
        if (dn_active) dn_bus <= dn_bus_i;


    // do not stall pipeline until it is primed
    assign dn_active = ~dn_val | dn_rdy;



`ifdef FORMAL

    initial begin
        // ensure reset is triggered at the start
        assume(rst == 1);
    end


    //
    // Check the proper relationship between interface bus signals
    //

    // up stream path holds data steady when stalled
    always @(posedge clk)
        if ( ~rst && $past(up_val && ~up_rdy)) begin
            assume($stable(up_bus));
        end


    // up stream path will only lower valid after a transaction
    always @(posedge clk)
        if ( ~rst && $past( ~rst) && $fell(up_val)) begin
            assume($past(up_rdy));
        end


    // up stream path will only lower ready after a transaction
    always @(posedge clk)
        if ( ~rst && $past( ~rst) && $fell(up_rdy)) begin
            assert($past(up_val));
        end


    // dn stream path holds data steady when stalled
    always @(posedge clk)
        if ( ~rst && $past(dn_val && ~dn_rdy)) begin
            assert($stable(dn_bus));
        end


    // dn stream path will only lower valid after a transaction
    always @(posedge clk)
        if ( ~rst && $past( ~rst) && $fell(dn_val)) begin
            assert($past(dn_rdy));
        end


    // dn stream path will only lower ready after a transaction
    always @(posedge clk)
        if ( ~rst && $past( ~rst) && $fell(dn_rdy)) begin
            assume($past(dn_val));
        end


    //
    // Check that the down data is sourced from correct locations
    //

    // dn stream data sourced from up stream data
    always @(posedge clk)
        if ( ~rst && $past(dn_val && dn_rdy && up_rdy)) begin
            assert(dn_bus == $past(up_bus));
        end


    // dn stream data sourced from skid register
    always @(posedge clk)
        if ( ~rst && $past(dn_val && dn_rdy && ~up_rdy)) begin
            assert(dn_bus == $past(skid_bus));
        end


    //
    // Check that the valid up data is always stored somewhere
    //

    // valid up stream data is passed to dn register when dn is not stalled
    always @(posedge clk)
        if ( ~rst && $past( ~rst && up_val && up_rdy && ~dn_val)) begin
            assert(($past(up_bus) == dn_bus) && dn_val);
        end


    // valid up stream data is passed to skid register when dn is stalled
    always @(posedge clk)
        if ( ~rst && $past( ~rst && up_val && up_rdy && dn_val && ~dn_rdy)) begin
            assert(($past(up_bus) == skid_bus) && dn_val);
        end


    //
    // Check that the skid register does not drop data
    //

    // skid register held steady when back pressure is being applied to up stream
    always @(posedge clk)
        if ( ~rst && $past( ~up_rdy)) begin
            assert($stable(skid_bus));
        end


    // skid register holds last up stream value when back pressure is applied to up stream
    always @(posedge clk)
        if ( ~rst && $fell(up_rdy)) begin
            assert(skid_bus == $past(up_bus));
        end
`endif

endmodule

`default_nettype wire

