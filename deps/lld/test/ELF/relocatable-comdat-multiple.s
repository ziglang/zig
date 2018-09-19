# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/relocatable-comdat-multiple.s -o %t2.o
# RUN: ld.lld -r %t.o %t2.o -o %t
# RUN: llvm-readobj -elf-section-groups %t | FileCheck %s

# CHECK:      Groups {
# CHECK-NEXT:   Group {
# CHECK-NEXT:     Name: .group
# CHECK-NEXT:     Index: 2
# CHECK-NEXT:     Link: 8
# CHECK-NEXT:     Info: 1
# CHECK-NEXT:     Type: COMDAT
# CHECK-NEXT:     Signature: aaa
# CHECK-NEXT:     Section(s) in group [
# CHECK-NEXT:       .text.a
# CHECK-NEXT:       .text.b
# CHECK-NEXT:     ]
# CHECK-NEXT:   }
# CHECK-NEXT:   Group {
# CHECK-NEXT:     Name: .group
# CHECK-NEXT:     Index: 5
# CHECK-NEXT:     Link: 8
# CHECK-NEXT:     Info: 6
# CHECK-NEXT:     Type: COMDAT
# CHECK-NEXT:     Signature: bbb
# CHECK-NEXT:     Section(s) in group [
# CHECK-NEXT:       .text.c
# CHECK-NEXT:       .text.d
# CHECK-NEXT:     ]
# CHECK-NEXT:   }
# CHECK-NEXT: }

.section .text.a,"axG",@progbits,aaa,comdat
.section .text.b,"axG",@progbits,aaa,comdat
