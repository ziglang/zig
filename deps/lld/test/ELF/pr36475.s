# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "PHDRS {" > %t.script
# RUN: echo " ph_text PT_LOAD FLAGS (0x1 | 0x4);" >> %t.script
# RUN: echo " ph_data PT_LOAD FLAGS (0x2 | 0x4);" >> %t.script
# RUN: echo "}" >> %t.script
# RUN: echo "SECTIONS {" >> %t.script
# RUN: echo " .text : { *(.text*) } : ph_text" >> %t.script
# RUN: echo " . = ALIGN(0x4000);" >> %t.script
# RUN: echo " .got.plt : { BYTE(42); *(.got); } : ph_data" >> %t.script
# RUN: echo "}" >> %t.script
# RUN: ld.lld -T %t.script %t.o -o %t.elf
# RUN: llvm-readobj -l -elf-output-style=GNU %t.elf | FileCheck %s

# CHECK: Section to Segment mapping:
# CHECK-NEXT: Segment Sections...
# CHECK-NEXT: 00 .text executable
# CHECK-NEXT: 01 .got.plt

.text
.globl _start
.type _start,@function
_start:
    callq custom_func
    ret

.section executable,"ax",@progbits
.type custom_func,@function
custom_func:
    ret
