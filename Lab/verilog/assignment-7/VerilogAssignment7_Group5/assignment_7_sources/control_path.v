// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module control_path(
    input wire clk,
    input wire reset,
    input wire start,
    output reg ldInput,
    output reg ldProduct,
    output reg busy,
    output reg done
);
    parameter S0 = 2'b00, S1 = 2'b01, S2 = 2'b10;
    reg [1:0] state, next_state;

    always @(posedge clk or posedge reset) begin
        if(reset) state <= S0;
        else state <= next_state;
    end

    always @(*) begin
        ldInput = 1'b0;
        ldProduct = 1'b0;
        busy = 1'b0;
        done = 1'b0;
        next_state = state;

        case (state)
            S0: begin
                if(start) begin
                    ldInput = 1'b1;
                    busy = 1'b1;
                    next_state = S1;
                end
            end
            S1: begin
                busy = 1'b1;
                ldProduct = 1'b1;
                next_state = S2;
            end
            S2: begin
                done = 1'b1;
                if(!start) next_state = S0;
            end
            default : next_state = S0;
        endcase
    end
endmodule
