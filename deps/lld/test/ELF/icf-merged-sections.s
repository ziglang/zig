# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --icf=all --ignore-data-address-equality --print-icf-sections | FileCheck -allow-empty --check-prefix=NOICF %s
# RUN: llvm-readobj -S --section-data %t | FileCheck %s

# Check that merge synthetic sections are not merged by ICF.

# NOICF-NOT: selected section <internal>:(.rodata)

# CHECK:      Name: .rodata
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_MERGE
# CHECK-NEXT: ]
# CHECK-NEXT: Address:
# CHECK-NEXT: Offset:
# CHECK-NEXT: Size: 16
# CHECK-NEXT: Link:
# CHECK-NEXT: Info:
# CHECK-NEXT: AddressAlignment: 1
# CHECK-NEXT: EntrySize: 0
# CHECK-NEXT: SectionData (
# CHECK-NEXT:   0000: 67452301 10325476 67452301 10325476

.section .rodata.cst4,"aM",@progbits,4
rodata4:
  .long 0x01234567
  .long 0x76543210
  .long 0x01234567
  .long 0x76543210

.section .rodata.cst8,"aM",@progbits,8
rodata8:
  .long 0x01234567
  .long 0x76543210
