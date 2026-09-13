.data
  input_prompt_1: .asciiz "Enter the first number: "
  input_prompt_2: .asciiz "Enter the second number: "
  output_prompt: .asciiz "The LCM of the input numbers is: "
  negative_input_prompt: .asciiz "Please enter only positive numbers "
  newline: .asciiz "\n"

.text
.globl main

main:
  la $a0, input_prompt_1
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  move $t0, $v0

  la $a0, input_prompt_2
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  move $t1, $v0

  blez $t0, negative_input
  blez $t1, negative_input

  move $a0, $t0
  move $a1, $t1

lcm_loop:
  beq $a0, $a1, lcm_found
  blt $a0, $a1, smaller
  bgt $a0, $a1, greater

smaller:
  add $a0, $a0, $t0
  b lcm_loop


greater:
  add $a1, $a1, $t1
  b lcm_loop


lcm_found:
  la $a0, output_prompt
  li $v0, 4
  syscall

  move $a0, $a1
  li $v0, 1
  syscall

  la $a0, newline
  li $v0, 4
  syscall

  b exit


negative_input:
  la $a0, negative_input_prompt
  li $v0, 4
  syscall

  b exit

exit:
  li $v0, 10
  syscall
