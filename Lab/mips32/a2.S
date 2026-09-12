.data
string_prompt:
    .asciiz "Please enter a string: "
end_prompt:
    .asciiz "Do you want to terminate the program (Y/N)? "
out_msg:
    .asciiz "\nThe encoded string is: "
newline:
    .asciiz "\n"
map:
    .word 4, 5, 7, 2, -4, -2, -5, 1, -1, -7
input:
    .space 100
output:
    .space 100
choice:
    .space 4

.text
   .globl main

main:
    b input_loop

input_loop:
    # Input String Prompt
    la $a0, string_prompt
    li $v0, 4
    syscall

    # Input the string
    la $a0, input
    li $a1, 100
    li $v0, 8
    syscall

    la $t0, input
    la $t1, output

    li $s0, 0x30
    li $s1, 0x39

main_loop:
    lb $t2, 0($t0)
    beq $t2, 0xA, exit_loop
    beqz $t2, exit_loop

    blt $t2, $s0, continue_skip
    bgt $t2, $s1, continue_skip

    sub $t5, $t2, $s0

    jal convert

    sb $t3, 0($t1)
    addu $t1, $t1, 1

continue_skip:
    addu $t0, $t0, 1
    b main_loop

exit_loop:
    sb $zero, 0($t1)

    # Print output prefix message
    la $a0, out_msg
    li $v0, 4
    syscall

    # Print the constructed output string
    la $a0, output
    li $v0, 4
    syscall

    # Output Newline
    la $a0, newline
    li $v0, 4
    syscall

    # Output Newline
    la $a0, newline
    li $v0, 4
    syscall

    # Ask the user if they want to terminate
    la $a0, end_prompt
    li $v0, 4
    syscall

    # Read Y/N character from user
    la $a0, choice
    li $a1, 4
    li $v0, 8
    syscall

    lb $t9, choice

    beq $t9, 0x59, exit
    beq $t9, 0x79, exit

    # Output Newline
    la $a0, newline
    li $v0, 4
    syscall

    b input_loop

exit:
    li $v0, 10
    syscall


convert:
    la $t6, map
    sll $t7, $t5, 2
    addu $t6, $t6, $t7
    lw $t8, 0($t6)

    addu $t3, $t2, $t8
    jr $ra
