# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { }" > %t.script
# RUN: ld.lld -T %t.script %t.o -o %t
# RUN: llvm-readobj -S -l %t | FileCheck %s

# CHECK:        Name: .tbss
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_TLS
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 8
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT: }
# CHECK-NEXT: Section {
# CHECK-NEXT:   Index:
# CHECK-NEXT:   Name: foo
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_TLS
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address:
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size: 1

# CHECK:      Type: PT_TLS
# CHECK-NEXT: Offset:
# CHECK-NEXT: VirtualAddress:
# CHECK-NEXT: PhysicalAddress:
# CHECK-NEXT: FileSize: 0
# CHECK-NEXT: MemSize: 9

.section        .tbss,"awT",@nobits
.quad   0
.section        foo,"awT",@nobits
.byte 0
