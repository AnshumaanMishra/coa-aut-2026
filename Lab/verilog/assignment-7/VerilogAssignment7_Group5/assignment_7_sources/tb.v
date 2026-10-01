// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

`timescale 1ns/1ps
module testbench();
    reg clk, reset, start;
    reg signed [31:0] multiplier, multiplicand;
    wire signed [63:0] product;
    wire busy, done;

    fast_booth_multiplier_32 DUT(clk, reset, start, multiplier, multiplicand, product, busy, done);

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
    end

    always #50
        clk = ~clk;

    initial begin
        $monitor($time, " M = %d, Q = %d, M * Q = %d", multiplicand, multiplier, product);

        #125 reset = 0;

        #50 multiplicand = 32'd13; multiplier = -32'd22; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = 32'd100; multiplier = 32'd25; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = -32'd100; multiplier = 32'd25; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = -32'd100; multiplier = -32'd25; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = 32'd0; multiplier = 32'd123456; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = 32'd1; multiplier = -32'd123456; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = 32'd2147483647; multiplier = 32'd1; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = -32'd2147483648; multiplier = 32'd1; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 multiplicand = -32'd2147483648; multiplier = -32'd1; start = 1;
        #150 start = 0;
        wait(done);
        #50;

        #50 $finish;
    end
endmodule
