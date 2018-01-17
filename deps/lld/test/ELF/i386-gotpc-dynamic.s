# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
# RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
# RUN: llvm-readobj -s %t.so | FileCheck %s
# RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=DISASM %s

# CHECK:       Section {
# CHECK:        Index: 7
# CHECK-NEXT:   Name: .got
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x2030
# CHECK-NEXT:   Offset:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Link:
# CHECK-NEXT:   Info:
# CHECK-NEXT:   AddressAlignment:
# CHECK-NEXT:   EntrySize:
# CHECK-NEXT: }

## 0x1000 + 4144 = 0x2030
# DISASM: 1000: {{.*}} movl $4144, %eax

.section .foo,"ax",@progbits
foo:
 movl $bar@got-., %eax # R_386_GOTPC

.local bar
bar:
