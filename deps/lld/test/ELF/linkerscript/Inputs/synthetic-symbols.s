.global _start
_start:
 nop

.section .foo,"a"
 .quad 0

.section .bar,"a"
 .long 0

.section .dah,"ax",@progbits
 .cfi_startproc
 nop
 .cfi_endproc

.global _begin_sec, _end_sec, _end_sec_abs
