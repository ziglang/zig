# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %tout --unresolved-symbols=ignore-all -pie
# RUN: llvm-readobj -r %tout | FileCheck %s

# CHECK:      Relocations [
# CHECK-NEXT:   Section ({{.*}}) .rela.plt {
# CHECK-NEXT:     0x3018 R_X86_64_JUMP_SLOT foo 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

_start:
callq foo@PLT
