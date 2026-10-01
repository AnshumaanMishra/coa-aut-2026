module data_path (
    clk,
    pc_enable,
    ic_enable,
    hi_lo_enable,
    reg_write,
    force_rs_zero,
    rt_sel,
    reg_dst,
    alu_src,
    alu_func,
    pc_src,
    br_type,
    is_branch,
    mem_read,
    mem_write,
    reg_in_src,
    opcode,
    fn_sel
);
  input clk, pc_enable, ic_enable, hi_lo_enable, reg_write, mem_read;
  input mem_write, alu_src, is_branch, force_rs_zero;
  input [2:0] rt_sel;
  input [1:0] reg_dst, pc_src, reg_in_src;
  input [2:0] br_type;
  input [5:0] alu_func;
  output [5:0] opcode, fn_sel;

  wire [31:0] next_pc, pc_out;
  program_counter pc (
      .clk(clk),
      .next_pc(next_pc),
      .pc_write_en(pc_enable),
      .pc_out(pc_out)
  );

  wire [4:0] rs, rd, rt, shamt;
  wire [15:0] imm;
  wire [25:0] jta;
  instruction_cache ic (
      .clk(clk),
      .ena(1'b1),
      .ic_enable(ic_enable),
      .pc(next_pc),
      .rs(rs),
      .rt(rt),
      .rd(rd),
      .shamt(shamt),
      .imm(imm),
      .jta(jta),
      .opcode(opcode),
      .fn_sel(fn_sel)
  );

  wire [4:0] rd_in;
  mux_4to1 #(
      .WIDTH(5)
  ) reg_dst_mux (
      .I0(rt),  // When destination is rt
      .I1(rd),  // When destination is 3rd reg
      .I2(5'b10001),  // When destination is $lo
      .I3(5'b01111),  // When destination is $ra = 15
      .sel(reg_dst),
      .O(rd_in)
  );

  wire [4:0] rt_addr;
  mux_8to1 #(
      .WIDTH(5)
  ) rt_sel_mux (
      .I0 (rt),
      .I1 (rd),
      .I2 (5'b0),
      .I3 (5'b10000),
      .I4 (5'b10001),
      .I5 (5'b0),
      .I6 (5'b0),
      .I7 (5'b0),
      .sel(rt_sel),
      .O  (rt_addr)
  );

  wire [4:0] rs_addr;
  mux_2to1 #(
      .WIDTH(5)
  ) force_rs_zero_mux (
      .I0 (rs),
      .I1 (5'b0),
      .sel(force_rs_zero),
      .O  (rs_addr)
  );

  wire [31:0] rs_out, rt_out;
  wire [31:0] reg_in_hi, reg_in_lo;
  register_file rf (
      .clk(clk),
      .reg_write(reg_write),
      .hi_lo_enable(hi_lo_enable),
      .rs(rs_addr),
      .rt(rt_addr),
      .rd(rd_in),
      .reg_in_hi(reg_in_hi),
      .reg_in_lo(reg_in_lo),
      .rs_out(rs_out),
      .rt_out(rt_out)
  );

  wire [31:0] imm_se;
  sign_extender #(
      .WIDTH(32)
  ) se (
      .imm_in(imm),
      .se_imm(imm_se)
  );

  wire [31:0] imm_ext;
  mux_2to1 #(
      .WIDTH(32)
  ) imm_ext_mux (
      .I0 (imm_se),
      .I1 ({16'b0, imm}),
      .sel(alu_src & (alu_func[5:3] == 3'b011)),
      .O  (imm_ext)
  );

  wire [31:0] alu_src_rt_in;
  mux_2to1 #(
      .WIDTH(32)
  ) alu_src_rt_in_mux (
      .I0 (rt_out),
      .I1 (imm_ext),
      .sel(alu_src),
      .O  (alu_src_rt_in)
  );

  wire ovfl, gt, lt, ge, le, eq, ne;
  wire [31:0] alu_out_lo;
  alu al_unit (
      .x(rs_out),
      .y(alu_src_rt_in),
      .alu_func(alu_func),
      .hi_lo_enable(hi_lo_enable),
      .ovfl(ovfl),
      .alu_out_hi(reg_in_hi),
      .alu_out_lo(alu_out_lo),
      .lt(lt),
      .gt(gt),
      .le(le),
      .ge(ge),
      .eq(eq),
      .ne(ne)
  );

  wire [31:0] data_cache_output;
  data_cache dc (
      .clk(clk),
      .address(alu_out_lo),
      .data_input(rt_out),
      .read(mem_read),
      .write(mem_write),
      .data_out(data_cache_output)
  );

  wire [31:0] inc_pc;
  mux_4to1 #(
      .WIDTH(32)
  ) reg_in_mux (
      .I0 (data_cache_output),
      .I1 (alu_out_lo),
      .I2 (inc_pc),
      .I3 (32'b0),
      .sel(reg_in_src),
      .O  (reg_in_lo)
  );

  next_address_decoder nad (
      .rt(rt_out),
      .rs(rs_out),
      .jta(jta),
      .pc(pc_out),
      .lt(lt),
      .gt(gt),
      .le(le),
      .ge(ge),
      .eq(eq),
      .ne(ne),
      .ovfl(ovfl),
      .br_type(br_type),
      .is_branch(is_branch),
      .pc_src(pc_src),
      .incr_pc(inc_pc),
      .next_pc(next_pc)
  );

endmodule
