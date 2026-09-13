.data
  input_prompt: .asciiz "Enter the String: "
  output_prompt: .asciiz "The encoded String is: "
  newline: .asciiz "\n"
  input_string: .space 100
  output_string: .space 100
  mapping: .word '4', '6', '9', '5', '0', '3', '1', '8', '7', '2'

.text
.globl main

main: 
  li $s0, 48
  li $s1, 4

  la $a0, input_prompt
  li $v0, 4
  syscall

  la $a0, input_string
  li $v0, 8
  li $a1, 100
  syscall

  la $t0, input_string
  li $t3, 0
  la $t4, output_string
  la $t5, mapping
# t0: Address of the current character

loop:
  lb $t1, 0($t0)
  beq $t1, 0, exit
  blt $t1, '0', skip_and_continue
  bgt $t1, '9', skip_and_continue

  sub $t6, $t1, $s0
  mul $t6, $t6, $s1
  add $t7, $t5, $t6
  lw $t8, 0($t7)
  move $t1, $t8
  

skip_and_continue:
  sb $t1, 0($t4) 
  addi $t0, $t0, 1
  addi $t4, $t4, 1
  b loop

exit:

  la $a0, output_prompt
  li $v0, 4
  syscall

  la $a0, output_string
  li $v0, 4
  syscall

  la $a0, newline
  li $v0, 4
  syscall

  li $v0, 10
  syscall
