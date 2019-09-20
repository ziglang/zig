# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o

## Show what regular output gives to us.
# RUN: ld.lld %t.o -o %t1
# RUN: llvm-readelf -S -l  %t1 | FileCheck %s
# CHECK:      .rodata   PROGBITS 0000000000200158 000158 000008
# CHECK-NEXT: .text     PROGBITS 0000000000201000 001000 000001
# CHECK-NEXT: .aw       PROGBITS 0000000000202000 002000 000008
# CHECK-NEXT: .data     PROGBITS 0000000000202008 002008 000008
# CHECK-NEXT: .bss      NOBITS   0000000000202010 002010 000008
# CHECK:      Type
# CHECK-NEXT: PHDR
# CHECK-NEXT: LOAD 0x000000 0x0000000000200000

## With .text at 0 there is no space to allocate the headers.
# RUN: ld.lld -Ttext 0x0 -Tdata 0x4000 -Tbss 0x8000 %t.o -o %t2
# RUN: llvm-readelf -S -l %t2 | FileCheck %s --check-prefix=USER1
# USER1:      .text   PROGBITS 0000000000000000 001000 000001
# USER1-NEXT: .data   PROGBITS 0000000000004000 002000 000008
# USER1-NEXT: .bss    NOBITS   0000000000008000 002008 000008
# USER1-NEXT: .rodata PROGBITS 0000000000009000 003000 000008
# USER1-NEXT: .aw     PROGBITS 000000000000a000 004000 000008
# USER1:      Type
# USER1-NEXT: LOAD 0x001000 0x0000000000000000

## With .text at 0x1000 there is space to allocate the headers.
# RUN: ld.lld -Ttext 0x1000 -Tdata 0x4000 -Tbss 0x8000 %t.o -o %t3
# RUN: llvm-readelf -S -l  %t3 | FileCheck %s --check-prefix=USER2
# USER2:      .text   PROGBITS 0000000000001000 001000 000001
# USER2-NEXT: .data   PROGBITS 0000000000004000 002000 000008
# USER2-NEXT: .bss    NOBITS   0000000000008000 002008 000008
# USER2-NEXT: .rodata PROGBITS 0000000000009000 003000 000008
# USER2-NEXT: .aw     PROGBITS 000000000000a000 004000 000008
# USER2:      Type
# USER2-NEXT: PHDR
# USER2-NEXT: LOAD 0x000000 0x0000000000000000

## With .text well above 200000 we don't need to change the image base
# RUN: ld.lld -Ttext 0x201000 %t.o -o %t4
# RUN: llvm-readelf -S -l %t4 | FileCheck %s --check-prefix=USER3
# USER3:     .text   PROGBITS 0000000000201000 001000 000001
# USER3-NEX: .rodata PROGBITS 0000000000202000 002000 000008
# USER3-NEX: .aw     PROGBITS 0000000000203000 003000 000008
# USER3-NEX: .data   PROGBITS 0000000000203008 003008 000008
# USER3-NEX: .bss    NOBITS   0000000000203010 003010 000008
# USER3:      Type
# USER3-NEXT: PHDR
# USER3-NEXT: LOAD 0x000000 0x0000000000200000

.text
.globl _start
_start:
 nop

.section .rodata,"a"
 .quad 0

.section .aw,"aw"
 .quad 0

.section .data,"aw"
 .quad 0

.section .bss,"",@nobits
 .quad 0
