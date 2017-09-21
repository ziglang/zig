# REQUIRES: x86
# Verify that the fill between sections has a default of interrupt instructions
# (0xcc on x86/x86_64) for executable sections and zero for other sections.

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld %t1.o -o %t1.elf
# RUN: llvm-objdump -s %t1.elf > %t1.sections
# RUN: FileCheck %s --input-file %t1.sections --check-prefix=TEXT
# RUN: FileCheck %s --input-file %t1.sections --check-prefix=DATA

# RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.elf
# RUN: llvm-objdump -s %t2.elf > %t2.sections
# RUN: FileCheck %s --input-file %t2.sections --check-prefix=TEXT
# RUN: FileCheck %s --input-file %t2.sections --check-prefix=DATA

# TEXT: Contents of section .text:
# TEXT-NEXT: 11cccccc cccccccc cccccccc cccccccc
# TEXT-NEXT: 22
# DATA: Contents of section .data:
# DATA-NEXT: 33000000 00000000 00000000 00000000
# DATA-NEXT: 44

.section .text.1,"ax",@progbits
.align 16
.byte 0x11

.section .text.2,"ax",@progbits
.align 16
.byte 0x22

.section .data.1,"a",@progbits
.align 16
.byte 0x33

.section .data.2,"a",@progbits
.align 16
.byte 0x44
