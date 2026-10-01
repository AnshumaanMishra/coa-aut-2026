// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module carry_save_adder_64(
    input wire [63:0] x,
    input wire [63:0] y,
    input wire [63:0] z,
    output wire [63:0] s,
    output wire [63:0] c
);
    assign s = x ^ y ^ z;
    assign c = ((x & y) | (y & z) | (z & x)) << 1;
endmodule
