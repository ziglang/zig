.globl f1, f2
.section .text.f2, "ax"
f2:
  mov $60, %rdi
  call f1
