.data 
  input_prompt: .asciiz "Enter the number: "
  prime_prompt: .asciiz "The entered number is prime."
  composite_prompt: .asciiz "The entered number is not prime."
  invalid_input_prompt: .asciiz "The entered number is invalid."
  newline: .asciiz "\n"

.text
.globl main

main:
  li $s0, 1

  la $a0, input_prompt
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  ble $v0, $s0, invalid_input
  move $t0, $v0
  li $t1, 2
  move $t2, $t0

# t0: N
# t1: D
# t2: R
loop:
  beq $t1, $t0, end_loop
  bltz $t2, continue
  beqz $t2, composite
  sub $t2, $t2, $t1
  b loop

continue:
  addi $t1, $t1, 1
  move $t2, $t0
  b loop
  
composite:
  la $a0, composite_prompt
  li $v0, 4
  syscall
  
  b exit


end_loop:
  la $a0, prime_prompt
  li $v0, 4
  syscall
  
  b exit

invalid_input:
  la $a0, invalid_input_prompt
  li $v0, 4
  syscall

  b exit

exit:
  li $v0, 10
  syscall
