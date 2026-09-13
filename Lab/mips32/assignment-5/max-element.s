.data
  size_input_prompt: .asciiz "Please Enter array size: "
  elements_input_prompt: .asciiz "Please Enter the Elements: "
  output_message: .asciiz "The largest number in the array is: "
  invalid_size_message: .asciiz "The array size can be at most 20."

  .align 2

  array: .space 80

.text
.globl main

main:
  la $a0, size_input_prompt
  li $v0, 4
  syscall

  li $v0, 5
  syscall

  bgt $v0, 20, invalid_size
  ble $v0, 0, invalid_size

  move $s0, $v0
  move $t0, $v0

  la $a0, elements_input_prompt
  li $v0, 4
  syscall
  
  la $s1, array
  move $t1, $s1


elements_input:
  ble $t0, 0, continue
  
  li $v0, 5
  syscall

  sw $v0, 0($t1)
  addi $t0, $t0, -1
  addi $t1, $t1, 4

  b elements_input

continue:
  
  la $a0, output_message
  li $v0, 4
  syscall

  li $t0, 1
  move $t1, $s1

  jal find_max

  move $a0, $v0
  li $v0, 1
  syscall

  b exit

# t0: index
# t1: address
# t2: return address

find_max:
  beq $t0, $s0, base_case
  
  addi $sp, $sp, -12
  sw $t0, 8($sp)
  sw $t1, 4($sp)
  sw $ra, 0($sp)

  addi $t0, $t0, 1
  addi $t1, $t1, 4

  jal find_max

  lw $t0, 8($sp)
  lw $t1, 4($sp)
  lw $t2, 0($t1)
  lw $ra, 0($sp)
  
  blt $v0, $t2, replace_max
  b return

replace_max:
  move $v0, $t2
  b return

base_case:
  lw $v0, 0($t1)
  jr $ra

return:
  addi $sp, $sp, 12
  jr $ra

invalid_size:
  la $a0, invalid_size_message
  li $v0, 4
  syscall

  b exit

exit:
  li $v0, 10
  syscall
  
