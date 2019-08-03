.section .text.f6, "ax"
f6:
  mov $60, %rax
  mov $42, %rdi
  syscall

  .section .text.f7, "ax"
f7:
  mov $0, %rax
