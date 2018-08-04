# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .text.zed : { *(.text.foo) } .text.qux : { *(.text.bar) } }" > %t.script
# RUN: ld.lld -T %t.script --emit-relocs %t.o -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck %s

## Check we name relocation sections in according to
## their target sections names.

# CHECK: .text.zed
# CHECK: .text.qux
# CHECK: .rela.text.zed
# CHECK: .rela.text.qux

.section .text.foo,"ax"
foo:
 mov $bar, %rax

.section .text.bar,"ax"
bar:
 mov $foo, %rax
