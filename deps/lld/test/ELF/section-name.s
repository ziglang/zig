# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %tout
# RUN: llvm-objdump --section-headers  %tout | FileCheck %s
# REQUIRES: x86

.global _start
.text
_start:

.section .text.a,"ax"
.byte 0
.section .text.,"ax"
.byte 0
.section .rodata.a,"a"
.byte 0
.section .rodata,"a"
.byte 0
.section .data.a,"aw"
.byte 0
.section .data,"aw"
.byte 0
.section .bss.a,"aw",@nobits
.byte 0
.section .bss,"aw",@nobits
.byte 0
.section .foo.a,"aw"
.byte 0
.section .foo,"aw"
.byte 0
.section .data.rel.ro,"aw",%progbits
.byte 0
.section .data.rel.ro.a,"aw",%progbits
.byte 0
.section .data.rel.ro.local,"aw",%progbits
.byte 0
.section .data.rel.ro.local.a,"aw",%progbits
.byte 0
.section .tbss.foo,"aGwT",@nobits,foo,comdat
.byte 0
.section .gcc_except_table.foo,"aG",@progbits,foo,comdat
.byte 0
.section .tdata.foo,"aGwT",@progbits,foo,comdat
.byte 0

// CHECK:  1 .rodata  00000002
// CHECK:  2 .gcc_except_table 00000001
// CHECK:  3 .text         00000002
// CHECK:  4 .data         00000002
// CHECK:  5 .foo.a        00000001
// CHECK:  6 .foo          00000001
// CHECK:  7 .tdata        00000001
// CHECK:  8 .tbss         00000001
// CHECK:  9 .data.rel.ro  00000004
// CHECK: 10 .bss          00000002
// CHECK: 11 .comment      00000008
// CHECK: 12 .symtab       00000030
// CHECK: 13 .shstrtab     00000075
// CHECK: 14 .strtab       00000008
