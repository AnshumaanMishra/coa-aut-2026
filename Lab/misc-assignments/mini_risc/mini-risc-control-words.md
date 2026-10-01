# MiniRISC Control Word Reference
Disclaimer: This is not the version I wrote by hand. Unfortunately there was a critical error 
in that version and I did not want to write the whole thing again, so this is written by claude. 
However, all control word calculations were done by hand (yes, I am stupid)

## Instruction formats (bit positions)

| Format | 31:26 | 25:21 | 20:16 | 15:11 | 10:6 | 5:0 |
| ------ | ----- | ----- | ----- | ----- | ---- | --- |
| R      | op    | rd    | rs    | rt    | shamt | fn |
| I      | op    | rd    | rs    | imm[15:0] (overlaps rt/shamt/fn) | | |
| Branch | op    | rd (2nd compare reg) | rs | offset[15:0] | | |
| J      | op    | jta[25:0] | | | | |

Notes:
- `fn` in the I / branch / J formats is **not** a field (it is part of imm / offset), so every I-type instruction has its **own opcode** and the control path generates the ALU function. Only R-type (`op = 100000`) takes `alu_func` from instruction bits 5:0.
- `ST rd, imm(rs)` stores `rd`; branches compare `rs` with the register in the `rd` field (`BZ`: with 0). Branch target = `PC + 1 + sext(offset)` (word units). `BV` tests overflow of `rs - rd`.
- `rt_sel` controls a mux feeding `register_file.rt`'s read-address port directly: `000`=instruction's `rt` field (normal), `001`=`rd` field (ST's store value, or a conditional branch's 2nd compare register), `010`=R0 (MOVE, BZ), `011`=`$hi` (MFHI), `100`=`$lo` (MFLO). This replaces the old `force_rt_zero` signal, which couldn't scale to the HI/LO cases.
- `force_rs_zero` forces `register_file.rs`'s read-address to R0, independent of `rt_sel`. Needed by `LI` (`rd = 0 + imm`), `MFHI`, `MFLO` (`rd = 0 + $hi/$lo`) — all three reuse the ADD function with one operand hardwired to R0.
- `LI rd, imm` = `ADDI rd, R0, imm` with `force_rs_zero=1` (hardware-enforced, not assembler convention). `MOVE rd, rs` forces `rt_sel=010` so `rd = rs + 0`.
- `MFHI`/`MFLO` read the register file's dedicated `$hi`/`$lo` storage (populated by `MULU`'s `hi_lo_enable` write path) into an ordinary GPR via `rd = 0 + $hi/$lo`.
- Logic immediates (`ANDI/ORI/NORI/XORI`) are **zero** extended; every other immediate is sign extended (`imm_ext_mux` in `data_path.v`, selected by `alu_src & (alu_func[5:3]==011)`).
- Multi-cycle instructions (`LD`, `MUL`, `MULU`): the row shows the **commit (last) cycle**. In the first cycle `pc_en = ic_en = reg_wr = 0` (and `ld = 1` for `LD`), then the FSM waits in `WAIT` (1 cycle for `LD`, 33 for `MUL/MULU` placeholder) before committing.
- `NOP` has `pc_en = ic_en = 1` (advances PC normally). Only `HALT` stops the PC. Illegal opcodes also go to `DONE`.
- `ic_en` is the instruction-ROM enable; the ROM is addressed with `next_pc`, so PC and ROM output update on the same edge.

## NOP

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | NOP | 000000 | 1 | 1 | XX | 0 | 0 | X | XXXXXX | 0 | 0 | XX | 00 | 0 | XXX | 0 | 000 |

## R-type (`op = 100000`)

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | ADD | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 010000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 3 | SUB | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 010001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 4 | MUL | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 010010 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 5 | MULU | 100000 | 1 | 1 | 10 | 1 | 1 | 0 | 010011 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 6 | AND | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 011000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 7 | OR | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 011001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 8 | NOT | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 011010 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 9 | NOR | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 011011 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 10 | XOR | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 011100 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 11 | SLL | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 100000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 12 | SRL | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 100001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 13 | SRA | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 100010 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 14 | SLT | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 001000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 15 | SGT | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 001001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 16 | SLE | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 001010 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 17 | SGE | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 001011 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 18 | SEQ | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 001100 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 19 | SNE | 100000 | 1 | 1 | 01 | 0 | 1 | 0 | 001101 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |

## I-type ALU (one opcode each)

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20 | ADDI | 110000 | 1 | 1 | 01 | 0 | 1 | 1 | 010000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 21 | SUBI | 110001 | 1 | 1 | 01 | 0 | 1 | 1 | 010001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 22 | ANDI | 110010 | 1 | 1 | 01 | 0 | 1 | 1 | 011000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 23 | ORI | 110011 | 1 | 1 | 01 | 0 | 1 | 1 | 011001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 24 | NORI | 110100 | 1 | 1 | 01 | 0 | 1 | 1 | 011011 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 25 | XORI | 110101 | 1 | 1 | 01 | 0 | 1 | 1 | 011100 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 26 | SLLI | 110110 | 1 | 1 | 01 | 0 | 1 | 1 | 100000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 27 | SRLI | 110111 | 1 | 1 | 01 | 0 | 1 | 1 | 100001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 28 | SRAI | 111000 | 1 | 1 | 01 | 0 | 1 | 1 | 100010 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 29 | SLTI | 111001 | 1 | 1 | 01 | 0 | 1 | 1 | 001000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 30 | SGTI | 111010 | 1 | 1 | 01 | 0 | 1 | 1 | 001001 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 31 | SLEI | 111011 | 1 | 1 | 01 | 0 | 1 | 1 | 001010 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 32 | SGEI | 111100 | 1 | 1 | 01 | 0 | 1 | 1 | 001011 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 33 | SEQI | 111101 | 1 | 1 | 01 | 0 | 1 | 1 | 001100 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 34 | SNEI | 111110 | 1 | 1 | 01 | 0 | 1 | 1 | 001101 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |

## Constants / Move / HI-LO read

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 35 | LI | 100010 | 1 | 1 | 01 | 0 | 1 | 1 | 010000 | 0 | 0 | 01 | 00 | 0 | XXX | 1 | 000 |
| 36 | LUI | 100011 | 1 | 1 | 01 | 0 | 1 | 1 | 000000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 000 |
| 37 | MOVE | 100100 | 1 | 1 | 01 | 0 | 1 | 0 | 010000 | 0 | 0 | 01 | 00 | 0 | XXX | 0 | 010 |
| 38 | MFHI | 100001 | 1 | 1 | 01 | 0 | 1 | 0 | 010000 | 0 | 0 | 01 | 00 | 0 | XXX | 1 | 011 |
| 39 | MFLO | 100111 | 1 | 1 | 01 | 0 | 1 | 0 | 010000 | 0 | 0 | 01 | 00 | 0 | XXX | 1 | 100 |

## Memory

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 40 | LD | 100101 | 1 | 1 | 01 | 0 | 1 | 1 | 010000 | 1 | 0 | 00 | 00 | 0 | XXX | 0 | 000 |
| 41 | ST | 100110 | 1 | 1 | XX | 0 | 0 | 1 | 010000 | 0 | 1 | XX | 00 | 0 | XXX | 0 | 001 |

## Jumps

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 42 | B (J) | 101000 | 1 | 1 | XX | 0 | 0 | X | XXXXXX | 0 | 0 | XX | 01 | 0 | XXX | 0 | 000 |
| 43 | JAL | 101001 | 1 | 1 | 11 | 0 | 1 | X | XXXXXX | 0 | 0 | 10 | 01 | 0 | XXX | 0 | 000 |
| 44 | B (JR) | 101011 | 1 | 1 | XX | 0 | 0 | X | XXXXXX | 0 | 0 | XX | 10 | 0 | XXX | 0 | 000 |

## Conditional Branch (one opcode each)

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 45 | BEQ | 010000 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 001 | 0 | 001 |
| 46 | BZ | 010001 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 001 | 0 | 010 |
| 47 | BNE | 010010 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 010 | 0 | 001 |
| 48 | BLT | 010011 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 011 | 0 | 001 |
| 49 | BLE | 010100 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 100 | 0 | 001 |
| 50 | BGT | 010101 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 101 | 0 | 001 |
| 51 | BGE | 010110 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 110 | 0 | 001 |
| 52 | BV | 010111 | 1 | 1 | XX | 0 | 0 | 0 | XXXXXX | 0 | 0 | XX | 00 | 1 | 111 | 0 | 001 |

## HALT

| S.NO. | Opcode | `op` | `pc_en` | `ic_en` | `regdst` | `hi_lo` | `reg_wr` | `alu_src` | `fn` | `ld` | `st` | `reg_in` | `pc_src` | `is_br` | `br_t` | `force_rs_zero` | `rt_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 53 | HALT | 111111 | 0 | 0 | XX | 0 | 0 | X | XXXXXX | 0 | 0 | XX | 00 | 0 | XXX | 0 | 000 |
