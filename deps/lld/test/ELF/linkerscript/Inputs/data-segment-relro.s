.global _start
_start:
  .long bar
  jmp *bar2@GOTPCREL(%rip)

.section .data,"aw"
.quad 0

.zero 4
.section .foo,"aw"
.section .bss,"",@nobits
