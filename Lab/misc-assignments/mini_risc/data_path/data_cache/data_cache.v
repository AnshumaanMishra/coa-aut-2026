module data_cache (
    clk,
    address,
    data_input,
    read,
    write,
    data_out
);
  input [31:0] address, data_input;
  input clk, read, write;
  output [31:0] data_out;

  data_ram #(
      .ADDR(10),
      .DATA(32)
  ) dr (
      .clka (clk),
      .ena  (read | write),
      .addra(address[11:2]),
      .wea  (write),
      .dina (data_input),
      .douta(data_out)
  );

endmodule
