module mini_risc(clk, start, reset);
  input clk, start, reset;

  wire pc_enable, ic_enable, hi_lo_enable, reg_write, mem_read;
  wire mem_write, alu_src, is_branch, force_rs_zero;
  wire [2:0] rt_sel;
  wire [1:0] reg_dst, pc_src, reg_in_src;
  wire [2:0] br_type;
  wire [5:0] alu_func;
  wire [5:0] opcode, fn_sel;

  control_path control(
    .clk(clk),
    .start(start),
    .reset(reset),
    .opcode(opcode),
    .fn_sel(fn_sel),
    .pc_enable(pc_enable),
    .ic_enable(ic_enable),
    .hi_lo_enable(hi_lo_enable),
    .reg_write(reg_write),
    .force_rs_zero(force_rs_zero),
    .rt_sel(rt_sel),
    .reg_dst(reg_dst),
    .alu_src(alu_src),
    .alu_func(alu_func),
    .pc_src(pc_src),
    .br_type(br_type),
    .is_branch(is_branch),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .reg_in_src(reg_in_src)
  );

  data_path data(
    .clk(clk),
    .pc_enable(pc_enable),
    .ic_enable(ic_enable),
    .hi_lo_enable(hi_lo_enable),
    .reg_write(reg_write),
    .force_rs_zero(force_rs_zero),
    .rt_sel(rt_sel),
    .reg_dst(reg_dst),
    .alu_src(alu_src),
    .alu_func(alu_func),
    .pc_src(pc_src),
    .br_type(br_type),
    .is_branch(is_branch),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .reg_in_src(reg_in_src),
    .opcode(opcode),
    .fn_sel(fn_sel)
  );
endmodule
