# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
# RUN: echo "PHDRS { text PT_LOAD FILEHDR PHDRS; rand PT_OPENBSD_RANDOMIZE; } \
# RUN:       SECTIONS { . = SIZEOF_HEADERS; \
# RUN:         .text : { *(.text) } \
# RUN:         .openbsd.randomdata : { *(.openbsd.randomdata) } : rand }" > %t.script
# RUN: ld.lld --script %t.script %t.o -o %t
# RUN: llvm-readobj --program-headers -s %t | FileCheck %s

# CHECK:      ProgramHeader {
# CHECK:        Type: PT_OPENBSD_RANDOMIZE (0x65A3DBE6)
# CHECK-NEXT:   Offset: 0x74
# CHECK-NEXT:   VirtualAddress: 0x74
# CHECK-NEXT:   PhysicalAddress: 0x74
# CHECK-NEXT:   FileSize: 8
# CHECK-NEXT:   MemSize: 8
# CHECK-NEXT:   Flags [ (0x4)
# CHECK-NEXT:     PF_R (0x4)
# CHECK-NEXT:   ]
# CHECK-NEXT:   Alignment: 1
# CHECK-NEXT: }

.section .openbsd.randomdata, "a"
.quad 0
