# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  . = 0x1000; \
# RUN:  .aaa : AT(0x2000) { *(.aaa) } \
# RUN:  .bbb : { *(.bbb) } \
# RUN:  .ccc : AT(0x3000) { *(.ccc) } \
# RUN:  .ddd : AT(0x4000) { *(.ddd) } \
# RUN:  .text : { *(.text) } \
# RUN:  aaa_lma = LOADADDR(.aaa);  \
# RUN:  bbb_lma = LOADADDR(.bbb);  \
# RUN:  ccc_lma = LOADADDR(.ccc);  \
# RUN:  ddd_lma = LOADADDR(.ddd);  \
# RUN:  txt_lma = LOADADDR(.text); \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-objdump -t %t2 | FileCheck %s
# RUN: echo "SECTIONS { v = LOADADDR(.zzz); }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | FileCheck --check-prefix=ERROR %s

# CHECK:      0000000000002000         *ABS*     00000000 aaa_lma
# CHECK-NEXT: 0000000000002008         *ABS*     00000000 bbb_lma
# CHECK-NEXT: 0000000000003000         *ABS*     00000000 ccc_lma
# CHECK-NEXT: 0000000000004000         *ABS*     00000000 ddd_lma
# CHECK-NEXT: 0000000000004008         *ABS*     00000000 txt_lma
# ERROR: {{.*}}.script:1: undefined section .zzz

.global _start
_start:
 nop

.section .aaa, "a"
.quad 0

.section .bbb, "a"
.quad 0

.section .ccc, "a"
.quad 0

.section .ddd, "a"
.quad 0
