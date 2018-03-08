# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS {foo 0 : {*(foo*)} }" > %t.script
# RUN: ld.lld --hash-style=sysv -o %t --script %t.script %t.o -shared
# RUN: llvm-readobj -elf-output-style=GNU -l %t | FileCheck %s

# RUN: echo "SECTIONS {foo : {*(foo*)} }" > %t.script
# RUN: ld.lld --hash-style=sysv -o %t --script %t.script %t.o -shared
# RUN: llvm-readobj -elf-output-style=GNU -l %t | FileCheck %s

# There is not enough address space available for the header, so just start the PT_LOAD
# after it. Don't create a PT_PHDR as the header is not allocated.

# CHECK: Program Headers:
# CHECK-NEXT: Type  Offset   VirtAddr           PhysAddr
# CHECK-NEXT: LOAD  0x001000 0x0000000000000000 0x0000000000000000

# CHECK:      Section to Segment mapping:
# CHECK-NEXT:  Segment Sections...
# CHECK-NEXT:   00     foo .text .dynsym .hash .dynstr

.section foo, "a"
.quad 0
