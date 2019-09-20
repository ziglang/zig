# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/dynamic-list-weak-archive.s -o %t2.o
# RUN: rm -f %t.a
# RUN: llvm-ar rcs %t.a %t2.o
# RUN: echo "{ zed; };" > %t.list
# RUN: ld.lld -shared --dynamic-list %t.list %t1.o %t.a -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.plt {
# CHECK-NEXT:     0x3018 R_X86_64_JUMP_SLOT foo
# CHECK-NEXT:   }
# CHECK-NEXT: ]

callq foo@PLT
.weak foo
