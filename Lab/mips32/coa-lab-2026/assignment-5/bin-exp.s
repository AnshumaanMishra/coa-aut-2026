.data
  base_prompt: .asciiz "Enter the base: "
  exponent_prompt: .asciiz "Enter the exponent: "
  output_prompt: .asciiz "The answer is: "
  invalid_input_prompt: .asciiz "Please enter valid integers."

.text
.globl main

main:
  la $a0, base_prompt
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  ble $v0, -11, invalid_input
  bge $v0, 11, invalid_input

  move $s0, $v0
  
  la $a0, exponent_prompt
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  ble $v0, -1, invalid_input
  bge $v0, 10, invalid_input

  move $s1, $v0

  jal recursive_power
  move $s0, $v0

  la $a0, output_prompt 
  li $v0, 4
  syscall

  move $a0, $s0
  li $v0, 1
  syscall
  b exit


recursive_power:
  beqz $s1, base_case

  addi $sp, $sp, -12

  sw $ra, 8($sp)
  sw $s0, 4($sp)
  sw $s1, 0($sp)
  


  srl $s1, $s1, 1

  jal recursive_power
  
  mul $v0, $v0, $v0
  
  lw $s1, 0($sp)
  andi $t0, $s1, 1
  beqz $t0, continue
  mul $v0, $s0, $v0

continue:
  lw $ra, 8($sp)

  addi $sp, $sp, 12
  jr $ra

base_case:
  li $v0, 1
  jr $ra


invalid_input:
  la $a0, invalid_input_prompt
  li $v0, 4
  syscall

  b exit

exit:
  li $v0, 10
  syscall

  
