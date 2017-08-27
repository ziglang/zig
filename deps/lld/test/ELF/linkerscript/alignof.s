# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:   .aaa         : { *(.aaa) } \
# RUN:   .bbb         : { *(.bbb) } \
# RUN:   .ccc         : { *(.ccc) } \
# RUN:   _aaa = ALIGNOF(.aaa); \
# RUN:   _bbb = ALIGNOF(.bbb); \
# RUN:   _ccc = ALIGNOF(.ccc); \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck %s
# CHECK:      SYMBOL TABLE:
# CHECK:      0000000000000008         *ABS*     00000000 _aaa
# CHECK-NEXT: 0000000000000010         *ABS*     00000000 _bbb
# CHECK-NEXT: 0000000000000020         *ABS*     00000000 _ccc

## Check that we error out if trying to get alignment of
## section that does not exist.
# RUN: echo "SECTIONS { \
# RUN:   _aaa = ALIGNOF(.foo); \
# RUN: }" > %t.script
# RUN: not ld.lld -o %t1 --script %t.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR %s
# ERR: {{.*}}.script:1: undefined section .foo
.global _start
_start:
 nop

.section .aaa,"a"
 .align 8
 .quad 0

.section .bbb,"a"
 .align 16
 .quad 0

.section .ccc,"a"
 .align 32
 .quad 0
