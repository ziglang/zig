# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so

# RUN: echo "SECTIONS { \
# RUN:  . = SIZEOF_HEADERS; \
# RUN:  .plt  : { *(.plt) } \
# RUN:  .text : { *(.text) } \
# RUN:  . = DATA_SEGMENT_ALIGN (CONSTANT (MAXPAGESIZE), CONSTANT (COMMONPAGESIZE)); \
# RUN:  .dynamic        : { *(.dynamic) } \
# RUN:  .got            : { *(.got) } \
# RUN:  . = DATA_SEGMENT_RELRO_END (1 ? 24 : 0, .); \
# RUN:  .got.plt : { *(.got.plt) } \
# RUN:  .data : { *(.data) } \
# RUN:  .bss        : { *(.bss) } \
# RUN:  . = DATA_SEGMENT_END (.); \
# RUN:  }" > %t.script

## With relro or without DATA_SEGMENT_RELRO_END just aligns to
## page boundary.
# RUN: ld.lld -z norelro %t1.o %t2.so --script %t.script -o %t
# RUN: llvm-readobj -s %t | FileCheck %s
# RUN: ld.lld -z relro %t1.o %t2.so --script %t.script -o %t2
# RUN: llvm-readobj -s %t2 | FileCheck %s

# CHECK:       Section {
# CHECK:         Index:
# CHECK:         Name: .got
# CHECK-NEXT:    Type: SHT_PROGBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x10F0
# CHECK-NEXT:    Offset: 0x10F0
# CHECK-NEXT:    Size:
# CHECK-NEXT:    Link:
# CHECK-NEXT:    Info:
# CHECK-NEXT:    AddressAlignment:
# CHECK-NEXT:    EntrySize:
# CHECK-NEXT:  }
# CHECK-NEXT:  Section {
# CHECK-NEXT:    Index:
# CHECK-NEXT:    Name: .got.plt
# CHECK-NEXT:    Type: SHT_PROGBITS
# CHECK-NEXT:    Flags [
# CHECK-NEXT:      SHF_ALLOC
# CHECK-NEXT:      SHF_WRITE
# CHECK-NEXT:    ]
# CHECK-NEXT:    Address: 0x2000
# CHECK-NEXT:    Offset: 0x2000
# CHECK-NEXT:    Size:
# CHECK-NEXT:    Link:
# CHECK-NEXT:    Info:
# CHECK-NEXT:    AddressAlignment:
# CHECK-NEXT:    EntrySize:
# CHECK-NEXT:  }

.global _start
_start:
  .long bar
  jmp *bar2@GOTPCREL(%rip)

.section .data,"aw"
.quad 0

.zero 4
.section .foo,"aw"
.section .bss,"",@nobits
