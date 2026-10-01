// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module booth_encoder_radix4(
    input wire [2:0] bits,
    output reg zero,
    output reg negative,
    output reg double
);
    always @(*) begin
        zero = 1'b0;
        negative = 1'b0;
        double = 1'b0;
        case (bits)
            3'b000, 3'b111: begin zero = 1'b1; end
            3'b001, 3'b010: begin end // +1M
            3'b011: begin double = 1'b1; end // +2M
            3'b100: begin double = 1'b1; negative = 1'b1; end // -2M
            3'b101, 3'b110: begin negative = 1'b1;  end // -1M
            default: begin end
        endcase
    end
endmodule
