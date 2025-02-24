# Version 1.0.7
# fixed the problem that csrr read the address not the value

##
# Copyright (c) 1990-2023 James R. Larus.
# Copyright (c) 2023 LupLab.
#
# SPDX-License-Identifier: AGPL-3.0-only
##

# This a modified version of the default system code for VRV.

# It contains three parts:

# 1. The machine boot code, starting from global label
#    `__mstart`. This boot code sets up the trap vector, and jumps to
#    label `__user_bootstrap` in user mode.

# 2. The trap handler, which is called upon an exception (interrupts
#    are not enabled by default).
	
# 3. The small user bootstrap code, starting from global label
#    `__user_bootstrap`. This bootstrap code calls `main`, which is expected to
#     be defined by the user program. If main returns, the bootstrap code exits
#     with the value returned by main.

# You will need to modify the trap handler to:

# a) Save all registers

# b) Examine the cause to determine if it is a misaligned load word.

# c) If it IS a misaligned load word, it should patch up the
# result and resume execution at the next instruction.

# d) Otherwise, it should jump to the terminate operation
# which is the default printing routine from VRV's default
# system file.

	## Constants
.equ    PRINT_DEC  0
.equ    PRINT_HEX   1
.equ    PRINT_CHR   3
.equ    PRINT_STR   4
.equ    EXIT        20

.equ    NEWLN_CHR   '\n'
.equ    SPACE_CHR   ' '

.equ 	KSTACK_SIZE 4096
	
# YOU can add more constants here, and you probably will want to!

## System data
    .kdata
__m_exc:    .string "  Exception"
__m_int:    .string "  Interrupt"

__m_mcause: .string "\n    MCAUSE: "
__m_mepc:   .string "\n    MEPC:   "
__m_mtval:  .string "\n    MTVAL:  "

__e0:   .string " [Misaligned instruction address]"
__e1:   .string " [Instruction access fault]"
__e2:   .string " [Illegal instruction]"
__e3:   .string " [Breakpoint]"
__e4:   .string " [Misaligned load address]"
__e5:   .string " [Load access fault]"
__e6:   .string " [Misaligned store address]"
__e7:   .string " [Store access fault]"
__e8:   .string " [User-mode ecall]"
__e11:  .string " [Machine-mode ecall]"

__i3:   .string " [Software]"
__i7:   .string " [Timer]"
__i11:  .string " [External]"

__evec: .word __e0, __e1, __e2, __e3, __e4, __e5, __e6, __e7, __e8, 0, 0, __e11
__ivec: .word 0, 0, 0, __i3, 0, 0, 0, __i7, 0, 0, 0, __i11

	.align 2

	# A small stack for kernel data
kstack:  .zero   KSTACK_SIZE

## System code
    .ktext
### Boot code
    .globl __mstart
__mstart:
    la      t0, __mtrap
    csrw    mtvec, t0

	la      t0, __user_bootstrap
	csrw    mepc, t0

	# Allocates space so the trap handler has a
	# small stack and can therefore call functions
	# itself.
	la 	t0, kstack
	li	t1, KSTACK_SIZE
	add 	t0 t0 t1
	csrw   	mscratch, t0
	mret    # Enter user bootstrap

### Trap handler

### You will need to write your own trap handler functionality here.
__mtrap:
    jal store
    csrr s0 mcause
    csrr s1 mepc
    csrr s2 mtval
    lw s1 0(s1)

    # general cases jump to terminate
    mv a0 s0
    call printhex
    li t0 6
    bne s0 t0 terminate
    li t0 0x0000707F    # mask = 0000707F
    and t0 t0 s1
    li t1 0x00002003 # lw = 00002003
    bne t0 t1 terminate
	
    # lw and misaligned address
    lb t0 0(s2)
    lb t1 1(s2)
    lb t2 2(s2)
    lb t3 3(s2)
    slli t0 t0 3
    slli t1 t1 2
    slli t2 t2 1
    or t0 t0 t1
    or t2 t2 t3
    or t0 t0 t2     # t0 = value

    # put the value back to rd
    srli t1 s1 7
    li t2 0x0000001F # mask = 0000001F
    and t1 t1 t2 # t1 = rd
    li t2 4
    li t3 1
    beq t3 t1 cha1
    mul t1 t1 t2
    add t1 t1 sp
    addi t1 t1 -8
    sw t0 0(t1)

    # restore
    jal restore
    csrr s1 mepc
    addi s1 s1 4
    csrw mepc s1
    mret

cha1:
    mul t1 t1 t2
    add t1 t1 sp
    addi t1 t1 -4
    sw t0 0(t1)

    # restore
    jal restore
    csrr s1 mepc
    addi s1 s1 4
    csrw mepc s1
    mret

store:
    csrrw sp, mscratch, sp
    addi sp, sp, -120
    sw x1 0(sp)
    sw x3 4(sp)
    sw x4 8(sp)
    sw x5 12(sp)
    sw x6 16(sp)
    sw x7 20(sp)
    sw x8 24(sp)
    sw x9 28(sp)
    sw x10 32(sp)
    sw x11 36(sp)
    sw x12 40(sp)
    sw x13 44(sp)
    sw x14 48(sp)
    sw x15 52(sp)
    sw x16 56(sp)
    sw x17 60(sp)
    sw x18 64(sp)
    sw x19 68(sp)
    sw x20 72(sp)
    sw x21 76(sp)
    sw x22 80(sp)
    sw x23 84(sp)
    sw x24 88(sp)
    sw x25 92(sp)
    sw x26 96(sp)
    sw x27 100(sp)
    sw x28 104(sp)
    sw x29 108(sp)
    sw x30 112(sp)
    sw x31 116(sp)
    ret

restore:
    lw x1 0(sp)
    lw x3 4(sp)
    lw x4 8(sp)
    lw x5 12(sp)
    lw x6 16(sp)
    lw x7 20(sp)
    lw x8 24(sp)
    lw x9 28(sp)
    lw x10 32(sp)
    lw x11 36(sp)
    lw x12 40(sp)
    lw x13 44(sp)
    lw x14 48(sp)
    lw x15 52(sp)
    lw x16 56(sp)
    lw x17 60(sp)
    lw x18 64(sp)
    lw x19 68(sp)
    lw x20 72(sp)
    lw x21 76(sp)
    lw x22 80(sp)
    lw x23 84(sp)
    lw x24 88(sp)
    lw x25 92(sp)
    lw x26 96(sp)
    lw x27 100(sp)
    lw x28 104(sp)
    lw x29 108(sp)
    lw x30 112(sp)
    lw x31 116(sp)
    addi sp, sp, 120
    csrrw sp, mscratch, sp
    ret


	
# This code is taken from the default VRV system code.  It prints out
# a message indicating the cause of an unhandled exception.  We are
# keeping this in this form to make it easier for you to debug.

# It is allowed to trash registers (unlike the normal trap handler)
# because it never returns	
terminate:
    csrr    t0, mcause      # Get mcause CSR
    li      t1, 0x80000000
    and     t1, t0, t1      # mcause & 0x80000000
    beqz    t1, ____not_interrupt   # mcause has bit 31 set for an interrupt

    # 2a. Interrupt
    la      a0, __m_int     # Interrupt header message
    xor     t0, t0, t1      # Isolate interrupt code
    la      t1, __ivec      # Interrupt vector
    j       ____print_trap_message

    # 2b. Exception
____not_interrupt:
    la      a0, __m_exc     # Exception header message
    la      t1, __evec      # Isolate exception code

    # 3. Print header message
____print_trap_message:
    li      a7, PRINT_STR
    ecall

    # 4. Print vector entry for this exception/interrupt
    slli    a0, t0, 2       # mcause * 4
    add     a0, t1, a0      # Index in vector
    lw      a0, (a0)        # Entry from vector
    ecall

    # 5. Print mcause
    la      a0, __m_mcause
    ecall
    csrr    a0, mcause
    li      a7, PRINT_HEX
    ecall

    # 6. Print mepc
    la      a0, __m_mepc
    li      a7, PRINT_STR
    ecall
    csrr    a0, mepc
    li      a7, PRINT_HEX
    ecall

    # 7. Print mtval
    la      a0, __m_mtval
    li      a7, PRINT_STR
    ecall
    csrr    a0, mtval
    li      a7, PRINT_HEX
    ecall
    li      a0, NEWLN_CHR
    li      a7, PRINT_CHR
    ecall

    # Exit with code -1
    li      a0, -1
    li      a7, EXIT
    ecall



## User boot code
    .text
__user_bootstrap:
    # exit(main())
    jal     main
    li      a7, EXIT
    ecall

# Useful utility function
kprintstr:
	li a7, PRINT_STR
	ecall
	ret

