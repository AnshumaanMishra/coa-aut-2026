.data
  input_prompt_1: .asciiz "Enter the first number: "
  input_prompt_2: .asciiz "Enter the second number: "
  output_prompt: .asciiz "The GCD of the input numbers is: "
  newline: .asciiz "\n"

.text
.globl main

# t0: first number
# t1: second number
# Algorithm:
# 1. Keep subtracting the smaller number from the larger number
# 2. When you get zero, the non-zero element is the GCD

main:
  li $s0, -1

input_1:
  la $a0, input_prompt_1
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  bgez $v0, continue_1

negative_input_1:
  mul $v0, $v0, $s0

continue_1:
  move $t0, $v0


input_2:
  la $a0, input_prompt_2
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  bgez $v0, continue_2

negative_input_2:
  mul $v0, $v0, $s0

continue_2:
  move $t1, $v0


main_loop:
  beqz $t0, t1_is_gcd
  beqz $t1, t0_is_gcd
  beq $t0, $t1, t1_is_gcd
  bgt $t0, $t1, greater
  ble $t0, $t1, smaller

greater:
  sub $t0, $t0, $t1
  b main_loop

smaller:
  sub $t1, $t1, $t0
  b main_loop


t0_is_gcd:
  la $a0, output_prompt
  li $v0, 4
  syscall

  move $a0, $t0
  li $v0, 1
  syscall

  b exit



t1_is_gcd:
  la $a0, output_prompt
  li $v0, 4
  syscall

  move $a0, $t1
  li $v0, 1
  syscall

  b exit


exit:
  li $v0, 10
  syscall
