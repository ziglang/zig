# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -r %t.o -o %t
# RUN: llvm-readobj -elf-section-groups -s %t | FileCheck %s

## Check .foo was not merged.
# CHECK: Sections [
# CHECK:  Name: .foo
# CHECK:  Name: .foo
# CHECK:  Name: .foo

# CHECK:      Groups {
# CHECK-NEXT:   Group {
# CHECK-NEXT:     Name: .group
# CHECK-NEXT:     Index: 2
# CHECK-NEXT:     Link: 8
# CHECK-NEXT:     Info: 1
# CHECK-NEXT:     Type: COMDAT
# CHECK-NEXT:     Signature: bar
# CHECK-NEXT:     Section(s) in group [
# CHECK-NEXT:       .foo (3)
# CHECK-NEXT:     ]
# CHECK-NEXT:   }
# CHECK-NEXT:   Group {
# CHECK-NEXT:     Name: .group
# CHECK-NEXT:     Index: 4
# CHECK-NEXT:     Link: 8
# CHECK-NEXT:     Info: 2
# CHECK-NEXT:     Type: COMDAT
# CHECK-NEXT:     Signature: zed
# CHECK-NEXT:     Section(s) in group [
# CHECK-NEXT:       .foo (5)
# CHECK-NEXT:     ]
# CHECK-NEXT:   }
# CHECK-NEXT: }

.section .foo,"axG",@progbits,bar,comdat
.section .foo,"axG",@progbits,zed,comdat
.section .foo,"ax",@progbits
