// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module partial_product_generator(
    input wire signed [31:0] multiplicand,
    input wire zero,
    input wire negative,
    input wire double,
    input wire [4:0] shift_idx,
    output wire [63:0] pp
);
    wire [63:0] Mtemp = {{32{multiplicand[31]}}, multiplicand};
    wire [63:0] b = double ? (Mtemp << 1) : Mtemp;
    wire [63:0] neg = (~b) + 1'b1;
    wire [63:0] selected = zero ? 64'd0 : (negative ? neg : b);

    assign pp = selected << (shift_idx * 2);
endmodule
