module next_address_decoder (
    rt,
    rs,
    jta,
    pc,
    le,
    lt,
    gt,
    ge,
    ne,
    eq,
    ovfl,
    br_type,
    is_branch,
    pc_src,
    incr_pc,
    next_pc
);
  input [31:0] rs, rt;
  input [25:0] jta;
  input [31:0] pc;
  input ovfl, le, lt, gt, ge, ne, eq;
  input [2:0] br_type;
  input is_branch;
  input [1:0] pc_src;
  output [31:0] incr_pc, next_pc;

  wire ovfl_placeholder;
  wire [29:0] jta_extended, jta_sign_extended, rs_extracted, next_pc_holder;
  wire [31:0] x_ext, pc_ext, incr_pc_ext;

  wire [29:0] pc_word;
  assign pc_word = pc[31:2];

  assign jta_extended = {incr_pc_ext[29:26], jta};
  assign rs_extracted = rs[31:2];

  wire br_true;

  branch_condition_checker bcc (
      .eq(eq),
      .ne(ne),
      .gt(gt),
      .lt(lt),
      .le(le),
      .ge(ge),
      .ovfl(ovfl),
      .br_type(br_type),
      .is_branch(is_branch),
      .br_true(br_true)
  );


  sign_extender #(
      .WIDTH(30)
  ) se (
      .imm_in(jta[15:0]),
      .se_imm(jta_sign_extended)
  );

  wire [29:0] x;
  assign x = jta_sign_extended & {30{br_true}};

  assign x_ext  = {2'b00, x};
  assign pc_ext = {2'b00, pc_word};

  ripple_carry_adder add (
      .x(x_ext),
      .y(pc_ext),
      .cin(1'b1),
      .s(incr_pc_ext),
      .ovfl(ovfl_placeholder)
  );

  assign incr_pc = {incr_pc_ext[29:0], 2'b00};

  mux_4to1 #(
      .WIDTH(30)
  ) pc_src_mux (
      .I0(incr_pc_ext[29:0]),
      .I1(jta_extended),
      .I2(rs_extracted),
      .I3(30'b0),  // For syscalls
      .sel(pc_src),
      .O(next_pc_holder)
  );

  assign next_pc = {next_pc_holder, 2'b00};

endmodule
