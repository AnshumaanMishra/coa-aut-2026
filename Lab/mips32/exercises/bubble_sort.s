.data
array:
  .word 5, 6, 2, 7, 8, 1, 3, 4

array_size:
  .word 8

.text
.globl main

main:
  la $t0,array
  li $t1,0
  la $s1,array_size
  lw $s0,0($s1)
# $t0: array base pointer
# $t1: outer pointer
# $t2: inner pointer
outer_loop:
  addi $t4,$s0,-1
  bge  $t1,$t4,end
  li $t2,0
  j inner_loop

inner_loop:
  sub  $t4,$s0,$t1      # n - i
  addi $t4,$t4,-1       # n - i - 1
  bge  $t2,$t4,inner_exit  
  addi $t3,$t2,1

  sll $t5,$t2,2
  add $t5,$t5,$t0
  sll $t6,$t3,2
  add $t6,$t6,$t0
  
  lw $t7,0($t5)
  lw $t8,0($t6)
 
  bgt $t7,$t8,greater_than
  ble $t7,$t8,less_than
  b inner_loop
 
greater_than:

  move $t9,$t7
  move $t7,$t8
  move $t8,$t9
  
  sw $t7,0($t5)
  sw $t8,0($t6)

  addi $t2,$t2,1
  j inner_loop

less_than:
  addi $t2,$t2,1
  j inner_loop

inner_exit:
  addi $t1,$t1,1
  j outer_loop

end:
    la  $t0, array      # Pointer to array
    li  $t1, 0          # Index = 0

print_loop:
    bge $t1, $s0, exit

    sll $t2, $t1, 2     # Offset = index * 4
    add $t2, $t2, $t0   # Address of array[index]

    lw  $a0, 0($t2)
    li  $v0, 1          # Print integer
    syscall

    # Print a space
    li  $a0, ' '
    li  $v0, 11         # Print character
    syscall

    addi $t1, $t1, 1
    j print_loop

exit:
    li $v0, 10
    syscall
