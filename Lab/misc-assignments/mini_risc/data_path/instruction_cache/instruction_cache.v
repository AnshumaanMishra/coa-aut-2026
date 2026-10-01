module instruction_cache (
    clk,
    ena,
    ic_enable,
    pc,
    rs,
    rt,
    rd,
    shamt,
    imm,
    jta,
    opcode,
    fn_sel
);
  input clk, ena, ic_enable;
  input [31:0] pc;
  output [4:0] rs, rt, rd, shamt;
  output [15:0] imm;
  output [25:0] jta;
  output [5:0] opcode, fn_sel;

  wire [31:0] instruction;

  address_rom #(
      .ADDR(10),
      .DATA(32)
  ) rom (
      .clka (clk),
      .ena  (ena & ic_enable),
      .addra(pc[11:2]),
      .douta(instruction)
  );

  assign opcode = instruction[31:26];
  assign rd = instruction[25:21];
  assign rs = instruction[20:16];
  assign rt = instruction[15:11];
  assign shamt = instruction[10:6];
  assign fn_sel = instruction[5:0];
  assign imm = instruction[15:0];
  assign jta = instruction[25:0];

endmodule


