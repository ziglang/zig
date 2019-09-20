.global bar, _start

.section .text.foo,"aG",@progbits,group,comdat

.section .text
_start:
 .quad .text.foo
 .quad bar
