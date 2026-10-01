// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module clock_divider_counter(slow_clk, clk, reset);
    output slow_clk;
    input clk;
    input reset;

    reg [31:0] clk_div;

    always @(posedge clk or posedge reset) begin
    if (reset)
        clk_div <= 32'b0;
    else
        clk_div <= clk_div + 1'b1;
    end

    assign slow_clk = clk_div[0];

endmodule
