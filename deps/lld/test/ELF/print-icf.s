# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/print-icf.s -o %t1
# RUN: ld.lld %t %t1 -o %t2 --icf=all --print-icf-sections | FileCheck %s
# RUN: ld.lld %t %t1 -o %t2 --icf=all --no-print-icf-sections --print-icf-sections | FileCheck %s
# RUN: ld.lld %t %t1 -o %t2 --icf=all --print-icf-sections --no-print-icf-sections | FileCheck -allow-empty -check-prefix=PRINT %s

# CHECK: selected section {{.*}}:(.text.f2)
# CHECK:   removing identical section {{.*}}:(.text.f4)
# CHECK:   removing identical section {{.*}}:(.text.f7)
# CHECK: selected section {{.*}}:(.text.f1)
# CHECK:   removing identical section {{.*}}:(.text.f3)
# CHECK:   removing identical section {{.*}}:(.text.f5)
# CHECK:   removing identical section {{.*}}:(.text.f6)

# PRINT-NOT: selected
# PRINT-NOT: removing

.globl _start, f1, f2
_start:
  ret

.section .text.f1, "ax"
f1:
  mov $60, %rax
  mov $42, %rdi
  syscall

  .section .text.f2, "ax"
f2:
  mov $0, %rax

.section .text.f3, "ax"
f3:
  mov $60, %rax
  mov $42, %rdi
  syscall

.section .text.f4, "ax"
f4:
  mov $0, %rax

.section .text.f5, "ax"
f5:
  mov $60, %rax
  mov $42, %rdi
  syscall
