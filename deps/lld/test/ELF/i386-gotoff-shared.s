// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
// RUN: llvm-readelf -S %t.so | FileCheck %s
// RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=DISASM %s

bar:
        movl    bar@GOTOFF(%ebx), %eax
        mov     bar@GOT, %eax

// CHECK: .got.plt          PROGBITS        00003000

// 0x1000 - 0x3000 (.got.plt) = -8192

// DISASM:  1000: {{.*}} movl    -8192(%ebx), %eax
