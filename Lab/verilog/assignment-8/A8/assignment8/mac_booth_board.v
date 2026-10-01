module mac_booth_board(
    input wire clk,
    input wire reset,
    input wire signed [15:0] sw,
    output wire signed [15:0] led
);
wire signed [7:0] A = sw[7:0];
wire signed [7:0] B = sw[15:8];
wire signed [31:0] A32 = {{24{A[7]}}, A};
wire signed [31:0] B32 = {{24{B[7]}}, B};
wire signed [63:0] product;
wire slow_clk;

fast_booth_multiplier fast_booth_multiplier(
	.multiplier  (A32),
	.multiplicand(B32),
	.product     (product)
);

wire signed [15:0] product16 = product[15:0];

clock_divider_counter cdc(
    .clk(clk),
    .slow_clk(slow_clk),
    .reset(reset)
);

reg signed [15:0] accumulator;
always @(posedge slow_clk or posedge reset) begin
    if (reset)
        accumulator <= 16'd0;
    else
        accumulator <= accumulator + product16;
end
assign led = accumulator;


endmodule
