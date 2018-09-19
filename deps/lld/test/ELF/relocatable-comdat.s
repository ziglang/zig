# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -r %t.o %t.o -o %t
# RUN: llvm-readobj -elf-section-groups -sections %t | FileCheck %s

# CHECK:        Name: .text.bar
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_EXECINSTR
# CHECK-NEXT:     SHF_GROUP
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 8
# CHECK:      Section {
# CHECK-NEXT:   Index: 4
# CHECK-NEXT:   Name: .text.foo
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_EXECINSTR
# CHECK-NEXT:     SHF_GROUP
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 4

# CHECK:       Groups {
# CHECK-NEXT:    Group {
# CHECK-NEXT:      Name: .group
# CHECK-NEXT:      Index: 2
# CHECK-NEXT:      Link: 5
# CHECK-NEXT:      Info: 1 
# CHECK-NEXT:      Type: COMDAT
# CHECK-NEXT:      Signature: abc
# CHECK-NEXT:      Section(s) in group [
# CHECK-NEXT:        .text.bar
# CHECK-NEXT:        .text.foo
# CHECK-NEXT:      ]
# CHECK-NEXT:    }
# CHECK-NEXT:  }

.section .text.bar,"axG",@progbits,abc,comdat
.quad 42
.section .text.foo,"axG",@progbits,abc,comdat
.long 42
