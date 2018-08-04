# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/resolution-end.s -o %t2.o
# RUN: ld.lld -shared -o %t2.so %t2.o
# RUN: ld.lld --hash-style=sysv %t1.o %t2.so -o %t
# RUN: llvm-readobj -t -s -section-data  %t | FileCheck %s

# Test that we resolve _end to the this executable.

# CHECK:      Name: .text
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_EXECINSTR
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size:
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment:
# CHECK-NEXT: EntrySize:
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 80202000 00000000 80202000 00000000
# CHECK-NEXT: )

# CHECK:      Symbol {
# CHECK:        Name: _end
# CHECK-NEXT:   Value: 0x202080

# CHECK:      Symbol {
# CHECK:        Name: end
# CHECK-NEXT:   Value: 0x202080

.global _start
_start:
.quad _end
.quad end
