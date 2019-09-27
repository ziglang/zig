# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
# RUN: llvm-readelf -S %t.so | FileCheck %s
# RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=DISASM %s

# CHECK: .got.plt          PROGBITS        00003000

## 0x3000 - 0x1000 = 8192
# DISASM: 1000: {{.*}} movl $8192, %eax

.section .foo,"ax",@progbits
foo:
 movl $bar@got-., %eax # R_386_GOTPC

.local bar
bar:
