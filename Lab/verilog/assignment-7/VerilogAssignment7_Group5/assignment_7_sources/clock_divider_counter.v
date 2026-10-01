// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module clock_divider_counter(slow_clk, clk);
    output slow_clk;
    input clk;

    reg [25:0] clk_div;

    initial
        clk_div = 0;
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    assign slow_clk = clk;

endmodule
