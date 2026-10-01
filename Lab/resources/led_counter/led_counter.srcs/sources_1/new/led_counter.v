`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.08.2026 11:59:02
// Design Name: 
// Module Name: led_counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module led_counter (
    input  wire       clk,       
    input  wire       reset,     
    output wire [4:0] led
);


    reg [25:0] clk_div;

    always @(posedge clk or posedge reset) begin
        if (reset)
            clk_div <= 26'd0;
        else
            clk_div <= clk_div + 1'b1;
    end

    wire slow_clk;
    assign slow_clk = clk_div[25];


    reg [4:0] count;

    always @(posedge slow_clk or posedge reset) begin
        if (reset)
            count <= 5'd0;
        else
            count <= count + 1'b1;
    end

    assign led = count;

endmodule
