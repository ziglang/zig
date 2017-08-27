 .syntax unified
 .arm
 .section .R_ARM_CALL24_callee_low, "ax",%progbits
 .align 2
 .globl callee_low
 .type callee_low,%function
callee_low:
 bx lr

 .section .R_ARM_CALL24_callee_thumb_low, "ax",%progbits
 .balign 0x100
 .thumb
 .type callee_thumb_low,%function
 .globl callee_thumb_low
callee_thumb_low:
  bx lr

 .section .R_ARM_CALL24_callee_high, "ax",%progbits
 .balign 0x100
 .arm
 .globl callee_high
 .type callee_high,%function
callee_high:
 bx lr

 .section .R_ARM_CALL24_callee_thumb_high, "ax",%progbits
 .balign 0x100
 .thumb
 .type callee_thumb_high,%function
 .globl callee_thumb_high
callee_thumb_high:
  bx lr

 .globl blx_far
 .type   blx_far, %function
blx_far = 0x1010018
