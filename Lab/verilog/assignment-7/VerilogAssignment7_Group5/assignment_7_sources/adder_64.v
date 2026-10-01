// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module adder_64(
    input wire [63:0] a,
    input wire [63:0] b,
    output wire [63:0] sum
);
    assign sum = a + b;
endmodule
