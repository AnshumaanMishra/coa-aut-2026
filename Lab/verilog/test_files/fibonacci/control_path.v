module control_path (
    clk,
    reset,
    start,
    gt,
    sel0,
    sel1,
    selK,
    ld0,
    ld1,
    ldK,
    ldA
);
  input gt, reset, start, clk;
  output reg sel0, sel1, selK, ld0, ld1, ldK, ldA;

  localparam RESET = 3'b000;
  localparam START = 3'b001;
  localparam COMP = 3'b010;
  localparam DONE = 3'b011;
  localparam LOAD1 = 3'b100;
  localparam LOAD2 = 3'b101;

  reg [2:0] current_state, next_state;

  initial begin
    current_state <= RESET;
  end

  always @(posedge clk) begin
    if (reset) begin
      current_state <= RESET;
    end else begin
      current_state <= next_state;
    end
  end

  // always @(current_state) begin
  //   case (current_state)
  //     RESET: begin
  //       if (start) begin
  //         next_state <= START;
  //       end
  //     end
  //     START: begin
  //       next_state <= COMP;
  //     end
  //     COMP: begin
  //       if (~gt) begin
  //         next_state <= DONE;
  //       end
  //     end
  //     default: begin
  //     end
  //   endcase
  // end

  always @(*) begin
    ld0 <= 0;
    ld1 <= 0;
    ldK <= 0;
    ldA <= 0;
    next_state <= current_state;
    case (current_state)
      RESET: begin
        if (start) begin
          next_state <= START;
        end
      end
      START: begin
        sel0 <= 0;
        sel1 <= 0;
        selK <= 0;
        next_state <= LOAD1;
      end
      LOAD1: begin
        ld0 <= 1;
        ld1 <= 1;
        ldK <= 1;
        ldA <= 0;
        next_state <= COMP;
      end
      COMP: begin
        if (gt) begin
          sel0 <= 1;
          sel1 <= 1;
          selK <= 1;
          next_state <= LOAD2;
        end else begin
          ldA <= 1;
          next_state <= DONE;
        end
      end
      LOAD2: begin
        ld0 <= 1;
        ld1 <= 1;
        ldK <= 1;
        ldA <= 0;
        next_state <= COMP;
      end
      default: begin
      end
    endcase
  end


endmodule
