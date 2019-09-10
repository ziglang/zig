# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux \
# RUN:   %p/Inputs/relocation-copy-align-common.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t.so
# RUN: ld.lld --hash-style=sysv %t.o %t.so -o %t3
# RUN: llvm-readobj -S -r --expand-relocs %t3 | FileCheck %s

# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .bss
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x203000
# CHECK-NEXT:   Offset: 0x3000
# CHECK-NEXT:   Size: 16
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 8
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT: }

# CHECK:      Relocations [
# CHECK-NEXT:   Section {{.*}} .rela.dyn {
# CHECK-NEXT:     Relocation {
# CHECK-NEXT:       Offset: 0x203008
# CHECK-NEXT:       Type: R_X86_64_COPY
# CHECK-NEXT:       Symbol: foo
# CHECK-NEXT:       Addend: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.global _start
_start:
.comm sym1,4,4
movl $5, foo
