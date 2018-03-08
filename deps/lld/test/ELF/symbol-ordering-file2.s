# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "bar" > %t.order
# RUN: ld.lld --symbol-ordering-file %t.order -shared %t.o -o %t.so
# RUN: llvm-nm %t.so | FileCheck %s

# CHECK:      0000000000002000 d _DYNAMIC
# CHECK-NEXT: 0000000000001000 T bar
# CHECK-NEXT: 0000000000001004 T foo

        .section .text.foo,"ax",@progbits
        .align 4
        .global foo
foo:
        retq

        .section .text.bar,"ax",@progbits
        .align 4
        .global bar
bar:
        retq
