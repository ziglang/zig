// This input must be assembled by the GNU assembler, as llvm-mc does not emit
// the R_ARM_JUMP11 relocation for a Thumb narrow branch. This is permissible
// by the ABI for the ARM architecture as the range of the Thumb narrow branch
// is short enough (+- 2048 bytes) that widespread use would be impractical.
//
// The test case will use a pre compiled object arm-thumb-narrow-branch.o
 .syntax unified
 .section .caller, "ax",%progbits
 .thumb
 .align 2
 .type callers,%function
 .globl callers
callers:
 b.n callee_low_far
 b.n callee_low
 b.n callee_high
 b.n callee_high_far
 bx lr
