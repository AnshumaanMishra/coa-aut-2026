.data
  newline:
    .asciiz "\n"

.text 
  .globl main

main:
  li $v0,5
  syscall

  move $t0,$v0

  li $v0,5
  syscall

  move $t1,$v0

  # move $ra,$pc
  jal addition

   #move $ra,$pc
  jal endline
  
  # move $ra,$pc
  jal subtraction
  
  # move $ra,$pc
  jal endline
  
  j end


addition:
  add $a0,$t1,$t0
  li $v0,1
  syscall
  
  jr $ra

subtraction:
  sub $a0,$t0,$t1
  li $v0,1
  syscall
  
  jr $ra

endline:
  la $a0,newline
  li $v0,4
  syscall

  jr $ra

end:
  li $v0,10
  syscall
