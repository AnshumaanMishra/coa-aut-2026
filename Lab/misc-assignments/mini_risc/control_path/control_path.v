module control_path (
    clk,
    start,
    reset,
    opcode,
    fn_sel,
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
    reg_in_src
);
  output reg pc_enable, ic_enable, hi_lo_enable, reg_write, mem_read;
  output reg mem_write, alu_src, is_branch, force_rs_zero;
  output reg [2:0] rt_sel;
  output reg [1:0] reg_dst, pc_src, reg_in_src;
  output reg [2:0] br_type;
  output reg [5:0] alu_func;
  input [5:0] opcode, fn_sel;
  input clk, start, reset;

  reg [5:0] halt_period, next_halt_period;
  reg is_multi;
  reg [5:0] multi_cycles;

  localparam reg DONTCARE1BIT = 1'b0;
  localparam reg [1:0] DONTCARE2BIT = 2'b0;
  localparam reg [2:0] DONTCARE3BIT = 3'b0;
  localparam reg [3:0] DONTCARE4BIT = 4'b0;
  localparam reg [4:0] DONTCARE5BIT = 5'b0;
  localparam reg [5:0] DONTCARE6BIT = 6'b0;

  localparam reg [1:0] IDLE = 2'b00;
  localparam reg [1:0] RUN = 2'b01;
  localparam reg [1:0] WAIT = 2'b10;
  localparam reg [1:0] DONE = 2'b11;

  localparam reg [5:0] NOP = 6'b000000;
  localparam reg [5:0] HALT = 6'b111111;
  localparam reg [5:0] RTYPE = 6'b100000;
  localparam reg [5:0] LI = 6'b100010;
  localparam reg [5:0] LUI = 6'b100011;
  localparam reg [5:0] MOVE = 6'b100100;
  localparam reg [5:0] MFHI = 6'b100001;
  localparam reg [5:0] MFLO = 6'b100111;
  localparam reg [5:0] LD = 6'b100101;
  localparam reg [5:0] ST = 6'b100110;
  localparam reg [5:0] BUCON = 6'b101000;
  localparam reg [5:0] JAL = 6'b101001;
  localparam reg [5:0] JREG = 6'b101011;

  localparam reg [5:0] ADDI = 6'b110000;
  localparam reg [5:0] SUBI = 6'b110001;
  localparam reg [5:0] ANDI = 6'b110010;
  localparam reg [5:0] ORI = 6'b110011;
  localparam reg [5:0] NORI = 6'b110100;
  localparam reg [5:0] XORI = 6'b110101;
  localparam reg [5:0] SLLI = 6'b110110;
  localparam reg [5:0] SRLI = 6'b110111;
  localparam reg [5:0] SRAI = 6'b111000;
  localparam reg [5:0] SLTI = 6'b111001;
  localparam reg [5:0] SGTI = 6'b111010;
  localparam reg [5:0] SLEI = 6'b111011;
  localparam reg [5:0] SGEI = 6'b111100;
  localparam reg [5:0] SEQI = 6'b111101;
  localparam reg [5:0] SNEI = 6'b111110;

  localparam reg [5:0] BEQ = 6'b010000;
  localparam reg [5:0] BZ = 6'b010001;
  localparam reg [5:0] BNE = 6'b010010;
  localparam reg [5:0] BLT = 6'b010011;
  localparam reg [5:0] BLE = 6'b010100;
  localparam reg [5:0] BGT = 6'b010101;
  localparam reg [5:0] BGE = 6'b010110;
  localparam reg [5:0] BV = 6'b010111;

  localparam reg [5:0] ADD = 6'b010000;
  localparam reg [5:0] SUB = 6'b010001;
  localparam reg [5:0] MUL = 6'b010010;
  localparam reg [5:0] MULU = 6'b010011;

  localparam reg [5:0] AND = 6'b011000;
  localparam reg [5:0] OR = 6'b011001;
  localparam reg [5:0] NOT = 6'b011010;
  localparam reg [5:0] NOR = 6'b011011;
  localparam reg [5:0] XOR = 6'b011100;

  localparam reg [5:0] SLL = 6'b100000;
  localparam reg [5:0] SRL = 6'b100001;
  localparam reg [5:0] SRA = 6'b100010;

  localparam reg [5:0] SLT = 6'b001000;
  localparam reg [5:0] SGT = 6'b001001;
  localparam reg [5:0] SLE = 6'b001010;
  localparam reg [5:0] SGE = 6'b001011;
  localparam reg [5:0] SEQ = 6'b001100;
  localparam reg [5:0] SNE = 6'b001101;

  localparam reg [5:0] LUIF = 6'b000000;

  localparam reg [1:0] REGDSTRT = 2'b00;
  localparam reg [1:0] REGDSTRD = 2'b01;
  localparam reg [1:0] REGDSTLO = 2'b10;
  localparam reg [1:0] REGDSTRA = 2'b11;

  localparam reg ALUSRCRT = 1'b0;
  localparam reg ALUSRCIMM = 1'b1;

  localparam reg [1:0] REGINMEM = 2'b00;
  localparam reg [1:0] REGINALU = 2'b01;
  localparam reg [1:0] REGININCPC = 2'b10;
  localparam reg [1:0] REGINULL = 2'b11;

  localparam reg [1:0] PCSRCADD = 2'b00;
  localparam reg [1:0] PCSRCJTA = 2'b01;
  localparam reg [1:0] PCSRCREG = 2'b10;
  localparam reg [1:0] PCSRCSYS = 2'b11;

  localparam reg [2:0] BTNC = 3'b000;
  localparam reg [2:0] BTEQ = 3'b001;
  localparam reg [2:0] BTNE = 3'b010;
  localparam reg [2:0] BTLT = 3'b011;
  localparam reg [2:0] BTLE = 3'b100;
  localparam reg [2:0] BTGT = 3'b101;
  localparam reg [2:0] BTGE = 3'b110;
  localparam reg [2:0] BTV = 3'b111;

  localparam reg [2:0] RTSELRT = 3'b000;
  localparam reg [2:0] RTSELRD = 3'b001;
  localparam reg [2:0] RTSELZERO = 3'b010;
  localparam reg [2:0] RTSELHI = 3'b011;
  localparam reg [2:0] RTSELLO = 3'b100;

  reg [1:0] state, next_state;

  wire wait_done;
  assign wait_done = (state == WAIT) && (halt_period == 6'b0);

  initial begin
    state <= IDLE;
    halt_period <= 6'b0;
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      halt_period <= 6'b0;
    end else begin
      state <= next_state;
      halt_period <= next_halt_period;
    end
  end

  always @(*) begin
    pc_enable = 0;
    ic_enable = 0;
    reg_dst = DONTCARE2BIT;
    hi_lo_enable = 0;
    reg_write = 0;
    alu_src = DONTCARE1BIT;
    alu_func = DONTCARE6BIT;
    mem_read = 0;
    mem_write = 0;
    reg_in_src = DONTCARE2BIT;
    pc_src = PCSRCADD;
    is_branch = 0;
    br_type = DONTCARE3BIT;
    force_rs_zero = 0;
    rt_sel = RTSELRT;
    is_multi = 0;
    multi_cycles = 6'b0;
    next_state = state;
    next_halt_period = halt_period;

    case (state)
      IDLE: begin
        pc_enable = 1;
        ic_enable = 1;
        pc_src = PCSRCSYS;
        next_state = start ? RUN : IDLE;
      end
      RUN, WAIT: begin
        case (opcode)
          NOP: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = DONTCARE2BIT;
            hi_lo_enable = 0;
            reg_write = 0;
            alu_src = DONTCARE1BIT;
            alu_func = DONTCARE6BIT;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = DONTCARE2BIT;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
          end
          HALT: begin
            pc_enable = 0;
            ic_enable = 0;
            reg_dst = DONTCARE2BIT;
            hi_lo_enable = 0;
            reg_write = 0;
            alu_src = DONTCARE1BIT;
            alu_func = DONTCARE6BIT;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = DONTCARE2BIT;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = DONE;
          end
          RTYPE: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCRT;
            alu_func = fn_sel;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
            case (fn_sel)
              // MUL: begin
              // is_multi = 0;
              // multi_cycles = 6'd32;
              // end
              MULU: begin
                hi_lo_enable = 1;
                // is_multi = 0;
                // multi_cycles = 6'd32;
              end
              default: ;
            endcase
          end
          ADDI, SUBI, ANDI, ORI, NORI, XORI, SLLI, SRLI, SRAI,
          SLTI, SGTI, SLEI, SGEI, SEQI, SNEI: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCIMM;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
            case (opcode)
              ADDI: alu_func = ADD;
              SUBI: alu_func = SUB;
              ANDI: alu_func = AND;
              ORI: alu_func = OR;
              NORI: alu_func = NOR;
              XORI: alu_func = XOR;
              SLLI: alu_func = SLL;
              SRLI: alu_func = SRL;
              SRAI: alu_func = SRA;
              SLTI: alu_func = SLT;
              SGTI: alu_func = SGT;
              SLEI: alu_func = SLE;
              SGEI: alu_func = SGE;
              SEQI: alu_func = SEQ;
              default: alu_func = SNE;
            endcase
          end
          LI: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCIMM;
            alu_func = ADD;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 1;
            rt_sel = RTSELRT;
            next_state = RUN;
          end
          LUI: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCIMM;
            alu_func = LUIF;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
          end
          MOVE: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCRT;
            alu_func = ADD;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELZERO;
            next_state = RUN;
          end
          MFHI: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCRT;
            alu_func = ADD;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 1;
            rt_sel = RTSELHI;
            next_state = RUN;
          end
          MFLO: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCRT;
            alu_func = ADD;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGINALU;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 1;
            rt_sel = RTSELLO;
            next_state = RUN;
          end
          LD: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRD;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = ALUSRCIMM;
            alu_func = ADD;
            mem_read = (state == RUN);
            mem_write = 0;
            reg_in_src = REGINMEM;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            is_multi = 1;
            multi_cycles = 6'd0;
          end
          ST: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = DONTCARE2BIT;
            hi_lo_enable = 0;
            reg_write = 0;
            alu_src = ALUSRCIMM;
            alu_func = ADD;
            mem_read = 0;
            mem_write = 1;
            reg_in_src = DONTCARE2BIT;
            pc_src = PCSRCADD;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRD;
            next_state = RUN;
          end
          BUCON: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = DONTCARE2BIT;
            hi_lo_enable = 0;
            reg_write = 0;
            alu_src = DONTCARE1BIT;
            alu_func = DONTCARE6BIT;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = DONTCARE2BIT;
            pc_src = PCSRCJTA;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
          end
          JAL: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = REGDSTRA;
            hi_lo_enable = 0;
            reg_write = 1;
            alu_src = DONTCARE1BIT;
            alu_func = DONTCARE6BIT;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = REGININCPC;
            pc_src = PCSRCJTA;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
          end
          BEQ, BZ, BNE, BLT, BLE, BGT, BGE, BV: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = DONTCARE2BIT;
            hi_lo_enable = 0;
            reg_write = 0;
            alu_src = ALUSRCRT;
            alu_func = SUB;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = DONTCARE2BIT;
            pc_src = PCSRCADD;
            is_branch = 1;
            force_rs_zero = 0;
            rt_sel = (opcode == BZ) ? RTSELZERO : RTSELRD;
            next_state = RUN;
            case (opcode)
              BEQ:     br_type = BTEQ;
              BZ:      br_type = BTEQ;
              BNE:     br_type = BTNE;
              BLT:     br_type = BTLT;
              BLE:     br_type = BTLE;
              BGT:     br_type = BTGT;
              BGE:     br_type = BTGE;
              default: br_type = BTV;
            endcase
          end
          JREG: begin
            pc_enable = 1;
            ic_enable = 1;
            reg_dst = DONTCARE2BIT;
            hi_lo_enable = 0;
            reg_write = 0;
            alu_src = DONTCARE1BIT;
            alu_func = DONTCARE6BIT;
            mem_read = 0;
            mem_write = 0;
            reg_in_src = DONTCARE2BIT;
            pc_src = PCSRCREG;
            is_branch = 0;
            br_type = DONTCARE3BIT;
            force_rs_zero = 0;
            rt_sel = RTSELRT;
            next_state = RUN;
          end
          default: next_state = DONE;
        endcase

        if (is_multi) begin
          pc_enable = wait_done;
          ic_enable = wait_done;
          reg_write = wait_done;
          if (state == RUN) begin
            next_halt_period = multi_cycles;
            next_state = WAIT;
          end else if (halt_period == 6'b0) begin
            next_state = RUN;
          end else begin
            next_halt_period = halt_period - 6'd1;
            next_state = WAIT;
          end
        end
      end
      DONE: next_state = DONE;
      default: next_state = IDLE;
    endcase
  end

endmodule
