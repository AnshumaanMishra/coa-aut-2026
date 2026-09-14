module fast_booth_encoder_test;

  reg signed [31:0] M;
  reg [2:0] Y;
  reg [3:0] shift;

  wire signed [31:0] O;

  integer passed;
  integer failed;
  integer expected;
  integer i;

  fast_booth_encoder dut(
    .M(M),
    .Y(Y),
    .shift(shift),
    .O(O)
  );

  initial begin
    passed = 0;
    failed = 0;

    // Test every Y and shift combination
    for (i = 0; i < 128; i = i + 1) begin

      Y     = i[2:0];
      shift = i[6:3];

      // Test with a fixed M
      M = 32'sd5;

      #1;

      case (Y)
        3'b000: expected = 0;
        3'b001: expected = 5;
        3'b010: expected = 5;
        3'b011: expected = 10;
        3'b100: expected = -10;
        3'b101: expected = -5;
        3'b110: expected = -5;
        3'b111: expected = 0;
      endcase

      expected = expected <<< shift;

      if (O === expected) begin
        passed = passed + 1;
      end
      else begin
        failed = failed + 1;
        $display("FAIL: Y=%b shift=%d M=%d | Expected=%d Got=%d",
                 Y, shift, M, expected, O);
      end
    end

    $display("--------------------------------");
    $display("Passed: %d", passed);
    $display("Failed: %d", failed);
    $display("Total : %d", passed + failed);
    $display("--------------------------------");

    $finish;
  end

endmodule
