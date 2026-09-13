.data
  input_prompt: .asciiz "Enter the String: "
  output_prompt: .asciiz "The sum of the digits is: "
  newline: .asciiz "\n"
  input_string: .space 100

.text
.globl main

main: 
  li $s0, 48

  la $a0, input_prompt
  li $v0, 4
  syscall

  la $a0, input_string
  li $v0, 8
  li $a1, 100
  syscall

  la $t0, input_string
  li $t3, 0

# t0: Address of the current character

loop:
  lb $t1, 0($t0)
  beq $t1, 0, exit
  blt $t1, '0', skip_and_continue
  bgt $t1, '9', skip_and_continue
  
  sub $t2, $t1, $s0
  add $t3, $t3, $t2

skip_and_continue:
  addi $t0, $t0, 1
  b loop

exit:
  la $a0, output_prompt
  li $v0, 4
  syscall

  move $a0, $t3
  li $v0, 1
  syscall

  la $a0, newline
  li $v0, 4
  syscall

  li $v0, 10
  syscall
