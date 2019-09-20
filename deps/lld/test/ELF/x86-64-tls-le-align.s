# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# -alignTo(p_memsz, p_align) = -alignTo(4, 64) = -64

# CHECK: movl %fs:-64, %eax

  movl %fs:a@TPOFF, %eax

.section .tbss,"awT"
.align 64
a:
.long 0
.size a, 4
