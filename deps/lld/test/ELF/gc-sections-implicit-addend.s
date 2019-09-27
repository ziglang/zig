# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --gc-sections
# RUN: llvm-readobj -S %t | FileCheck %s
# RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

# CHECK:      Name: .foo
# CHECK-NEXT: Type: SHT_PROGBITS
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_MERGE
# CHECK-NEXT:   SHF_STRINGS
# CHECK-NEXT: ]
# CHECK-NEXT: Address: 0x4000B4

# 0x4000B4 == 4194484
# DISASM: leal    4194484, %eax

        .section        .foo,"aMS",@progbits,1
        .byte 0

        .text
        .global _start
_start:
        leal    .foo, %eax
