.data
  input_prompt: .asciiz "Please enter a non-negative number: "
  output_prompt: .asciiz "The number of set bits in the number is: "
  newline: .asciiz "\n"
  invalid_input_prompt: .asciiz "Please enter a valid number!"

.text
.globl main

main:
  li $s0, 1
  la $a0, input_prompt
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  bgez $v0, continue
  
  la $a0, invalid_input_prompt 
  li $v0, 4
  syscall

  li $v0, 10
  syscall


continue:
  move $a0, $v0
  li $v0, 0
  move $t0, $a0
  
  jal count_set_bits

  move $t0, $v0

  la $a0, output_prompt
  li $v0, 4
  syscall

  move $a0, $t0
  li $v0, 1
  syscall

  li $v0, 10
  syscall

# v0: C
# t0: X

count_set_bits:
  andi $t1, $t0, 1
  add $v0, $v0, $t1
  srl $t0, $t0, $s0
  bnez $t0, count_set_bits

  jr $ra

