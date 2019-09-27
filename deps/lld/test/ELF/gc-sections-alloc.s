# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --gc-sections -shared
# RUN: llvm-readobj --sections  --section-data %t2 | FileCheck %s

# Non alloca section .bar should not keep section .foo alive.

# CHECK-NOT: Name: .foo

# CHECK:      Name: .bar
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size:
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment:
# CHECK-NEXT: EntrySize:
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 00000000 00000000                    |
# CHECK-NEXT: )


.section .foo,"a"
.byte 0

.section .bar
.quad .foo
