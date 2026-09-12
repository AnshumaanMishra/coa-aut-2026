.data
  input_message: .asciiz "Please enter the postfix expression: "
  output_message: .asciiz "The result of the input postfix expression is: "

  invalid_token_message: .asciiz "Error: Invalid token in input message"
  malformed_expression_message: .asciiz "Error: Malformed Expression"
  stack_overflow_message: .asciiz "Error: Stack Overflow"
  division_by_zero_message: .asciiz "Error: Division by Zero"

  .align 2

  operand_stack: .space 80
  input_stack: .space 200

.text
.globl main

main:
  li $s0, '0'

  la $a0, input_message
  li $v0, 4
  syscall

  la $a0, input_stack
  li $a1, 200
  li $v0, 8
  syscall
  
  li $t0, 0
  la $t1, input_stack
  li $t2, 0
  la $t3, operand_stack

# t0: index
# t1: address of input
# t2: size of operand_stack
# t3: operand stack pointer

  jal process
  
  beq $v1, 1, malformed_expression_print
  beq $v1, 2, invalid_token_print
  beq $v1, 3, stack_overflow_print
  beq $v1, 4, division_by_zero_print

  bne $t2, 1, malformed_expression_print

  move $s1, $v0

  la $a0, output_message
  li $v0, 4
  syscall

  move $a0, $s1
  li $v0, 1
  syscall

  b exit

process:
  lb $t4, 0($t1) # Current Character
  beq $t4, 0, input_end
  beq $t4, '\n', input_end
  beq $t4, ' ', continue
  bgt $t4, '9', check_invalid_token
  blt $t4, '0', check_invalid_token

  bgt $t2, 20, stack_overflow  

  sub $t4, $t4, $s0
  sw $t4, 0($t3)
  addi $t2, $t2, 1
  addi $t3, $t3, 4

  b continue

check_invalid_token:
  blt $t2, 2, malformed_expression  
  
  beq $t4, '+', op_plus 
  beq $t4, '-', op_minus 
  beq $t4, '*', op_mul
  beq $t4, '/', op_div

  # Error Condition: Invalid Token
  li $v1, 2
  jr $ra

op_plus:
  addi $t3, $t3, -4
  lw $t5, 0($t3)

  addi $t3, $t3, -4
  lw $t6, 0($t3)

  add $t7, $t5, $t6
  sw $t7, 0($t3)
  
  addi $t3, $t3, 4
  addi $t2, $t2, -1

  b continue

op_minus:
  addi $t3, $t3, -4
  lw $t5, 0($t3)

  addi $t3, $t3, -4
  lw $t6, 0($t3)

  sub $t7, $t6, $t5
  sw $t7, 0($t3)
  
  addi $t3, $t3, 4
  addi $t2, $t2, -1

  b continue

op_mul:
  addi $t3, $t3, -4
  lw $t5, 0($t3)

  addi $t3, $t3, -4
  lw $t6, 0($t3)

  mul $t7, $t6, $t5
  sw $t7, 0($t3)
  
  addi $t3, $t3, 4
  addi $t2, $t2, -1

  b continue

op_div:
  addi $t3, $t3, -4
  lw $t5, 0($t3)
  addi $t3, $t3, -4
  lw $t6, 0($t3)

  beqz $t5, division_by_zero

  div $t6, $t5
  mflo $t7
  sw $t7, 0($t3)
  addi $t3, $t3, 4
  addi $t2, $t2, -1

  b continue

malformed_expression:
  li $v1, 1
  jr $ra

stack_overflow:
  li $v1, 3
  jr $ra

division_by_zero:
  li $v1, 4
  jr $ra

malformed_expression_print:
  la $a0, malformed_expression_message
  li $v0, 4
  syscall

  b exit

invalid_token_print:
  la $a0, invalid_token_message
  li $v0, 4
  syscall

  b exit

stack_overflow_print:
  la $a0, stack_overflow_message
  li $v0, 4
  syscall

  b exit

division_by_zero_print:
  la $a0, division_by_zero_message
  li $v0, 4
  syscall

  b exit

continue:
  addi $t0, $t0, 1
  addi $t1, $t1, 1

  b process

input_end:
  li $v1, 0
  lw $v0, -4($t3)
  jr $ra

exit:
  li $v0, 10
  syscall

