# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:   .aaa         : { *(.aaa) } \
# RUN:   .bbb         : { *(.bbb) } \
# RUN:   .ccc         : { *(.ccc) } \
# RUN:   _aaa = SIZEOF(.aaa); \
# RUN:   _bbb = SIZEOF(.bbb); \
# RUN:   _ccc = SIZEOF(.ccc); \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t -section-headers %t1 | FileCheck %s
# CHECK:      Sections:
# CHECK-NEXT:  Idx Name          Size
# CHECK-NEXT:    0               00000000
# CHECK-NEXT:    1 .aaa          00000008
# CHECK-NEXT:    2 .bbb          00000010
# CHECK-NEXT:    3 .ccc          00000018
# CHECK:      SYMBOL TABLE:
# CHECK-NEXT:  0000000000000000 *UND* 00000000
# CHECK-NEXT:                   .text 00000000 _start
# CHECK-NEXT:  0000000000000008 *ABS* 00000000 _aaa
# CHECK-NEXT:  0000000000000010 *ABS* 00000000 _bbb
# CHECK-NEXT:  0000000000000018 *ABS* 00000000 _ccc

## SIZEOF(.nonexistent_section) should return 0.
# RUN: echo "SECTIONS { \
# RUN:   .aaa         : { *(.aaa) } \
# RUN:   .bbb         : { *(.bbb) } \
# RUN:   .ccc         : { *(.ccc) } \
# RUN:   _aaa = SIZEOF(.foo); \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t -section-headers %t1 | FileCheck -check-prefix=CHECK2 %s

# CHECK2: 0000000000000000 *ABS* 00000000 _aaa

.global _start
_start:
 nop

.section .aaa,"a"
 .quad 0

.section .bbb,"a"
 .quad 0
 .quad 0

.section .ccc,"a"
 .quad 0
 .quad 0
 .quad 0
