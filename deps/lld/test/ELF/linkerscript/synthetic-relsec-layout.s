# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { .foo : { *(.rela.dyn) } }" > %t.script
# RUN: ld.lld -T %t.script %t.o -o %t.so -shared
# RUN: llvm-readobj -r %t.so | FileCheck %s

# Check we are able to do custom layout for synthetic sections.
# (here we check we can place synthetic .rela.dyn into .foo).

# CHECK: Relocations [
# CHECK:   Section ({{.*}}) .foo {
# CHECK:     R_X86_64_64 .foo 0x0
# CHECK:   }

.data
.quad .foo
