# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Check that padding value works:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =0x1122 }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES %s
# YES: 66000011 22000011 22000011 22000011

# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =0x1100+0x22 }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES2 %s
# YES2: 66000011 22000011 22000011 22000011

## Confirming that address was correct:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =0x99887766 }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES3 %s
# YES3: 66998877 66998877 66998877 66998877

## Default padding value is 0x00:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=NO %s
# NO: 66000000 00000000 00000000 00000000

## Decimal value.
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =777 }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=DEC %s
# DEC: 66000003 09000003 09000003 09000003

## Invalid hex value:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =0x99XX }" > %t.script
# RUN: not ld.lld -o %t.out --script %t.script %t 2>&1 \
# RUN:   | FileCheck --check-prefix=ERR2 %s
# ERR2: malformed number: 0x99XX

## Check case with space between '=' and a value:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } = 0x1122 }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES %s

## Check case with optional comma following output section command:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =0x1122, .a : { *(.a*) } }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES %s

## Check we can use an artbitrary expression as a filler.
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } = ((0x11<<8) | 0x22) }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES %s

## Check case with space between '=' and expression:
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =((0x11 << 8) | 0x22) }" > %t.script
# RUN: ld.lld -o %t.out --script %t.script %t
# RUN: llvm-objdump -s %t.out | FileCheck -check-prefix=YES %s

## Check we report an error if expression value is larger than 32-bits.
# RUN: echo "SECTIONS { .mysec : { *(.mysec*) } =(0x11 << 32) }" > %t.script
# RUN: not ld.lld -o %t.out --script %t.script %t 2>&1 | FileCheck --check-prefix=ERR3 %s
# ERR3: filler expression result does not fit 32-bit: 0x1100000000

## Check we report an error if an expression use a symbol.
# RUN: echo "SECTIONS { foo = 0x11; .mysec : { *(.mysec*) } = foo }" > %t.script
# RUN: not ld.lld -o %t.out %t --script %t.script 2>&1 | FileCheck --check-prefix=ERR4 %s
# ERR4: symbol not found: foo

.section        .mysec.1,"a"
.align  16
.byte   0x66

.section        .mysec.2,"a"
.align  16
.byte   0x66

.globl _start
_start:
 nop
