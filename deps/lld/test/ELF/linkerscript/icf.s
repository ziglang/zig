# REQUIRES: x86

# RUN: echo "foo = 1; bar = 2;" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o %t.script -o %t --icf=all --print-icf-sections | count 0

.section .text.foo,"ax",@progbits
jmp foo

.section .text.bar,"ax",@progbits
jmp bar
