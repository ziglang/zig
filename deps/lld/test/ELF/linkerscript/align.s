# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

## Check that ALIGN command workable using location counter
# RUN: echo "SECTIONS {      \
# RUN:  . = 0x10000;         \
# RUN:  .aaa : { *(.aaa) }   \
# RUN:  . = ALIGN(4096);     \
# RUN:  .bbb : { *(.bbb) }   \
# RUN:  . = ALIGN(4096 * 4); \
# RUN:  .ccc : { *(.ccc) }   \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

## Check that the two argument version of ALIGN command works
# RUN: echo "SECTIONS {             \
# RUN:  . = ALIGN(0x1234, 0x10000); \
# RUN:  .aaa : { *(.aaa) }          \
# RUN:  . = ALIGN(., 4096);         \
# RUN:  .bbb : { *(.bbb) }          \
# RUN:  . = ALIGN(., 4096 * 4);     \
# RUN:  .ccc : { *(.ccc) }          \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT: Idx Name          Size      Address          Type
# CHECK-NEXT:   0               00000000 0000000000000000
# CHECK-NEXT:   1 .aaa          00000008 0000000000010000 DATA
# CHECK-NEXT:   2 .bbb          00000008 0000000000011000 DATA
# CHECK-NEXT:   3 .ccc          00000008 0000000000014000 DATA

## Check output sections ALIGN modificator
# RUN: echo "SECTIONS {                    \
# RUN:  . = 0x10000;                       \
# RUN:  .aaa : { *(.aaa) }                 \
# RUN:  .bbb : ALIGN(4096) { *(.bbb) }     \
# RUN:  .ccc : ALIGN(4096 * 4) { *(.ccc) } \
# RUN: }" > %t2.script
# RUN: ld.lld -o %t2 --script %t2.script %t
# RUN: llvm-objdump -section-headers %t2 | FileCheck %s

## Check use of variables in align expressions:
# RUN: echo "VAR = 0x1000;                                  \
# RUN: __code_base__ = 0x10000;                             \
# RUN: SECTIONS {                                           \
# RUN:  . = __code_base__;                                  \
# RUN:  .aaa : { *(.aaa) }                                  \
# RUN:  .bbb : ALIGN(VAR) { *(.bbb) }                       \
# RUN:  . = ALIGN(., VAR * 4);                              \
# RUN:  .ccc : { *(.ccc) }                                  \
# RUN:  __start_bbb = ADDR(.bbb);                           \
# RUN:  __end_bbb = ALIGN(__start_bbb + SIZEOF(.bbb), VAR); \
# RUN: }" > %t3.script
# RUN: ld.lld -o %t3 --script %t3.script %t
# RUN: llvm-objdump -section-headers %t3 | FileCheck %s
# RUN: llvm-objdump -t %t3 | FileCheck -check-prefix SYMBOLS %s

# SYMBOLS-LABEL: SYMBOL TABLE:
# SYMBOLS-NEXT: 0000000000000000         *UND*           00000000
# SYMBOLS-NEXT: 0000000000014008         .text           00000000 _start
# SYMBOLS-NEXT: 0000000000010000         *ABS*           00000000 __code_base__
# SYMBOLS-NEXT: 0000000000001000         *ABS*           00000000 VAR
# SYMBOLS-NEXT: 0000000000011000         .bbb            00000000 __start_bbb
# SYMBOLS-NEXT: 0000000000012000         .bbb            00000000 __end_bbb

## Check that ALIGN zero do nothing and does not crash #1.
# RUN: echo "SECTIONS { . = ALIGN(0x123, 0); .aaa : { *(.aaa) } }" > %t.script
# RUN: ld.lld -o %t4 --script %t.script %t
# RUN: llvm-objdump -section-headers %t4 | FileCheck %s -check-prefix=ZERO

# ZERO:      Sections:
# ZERO-NEXT: Idx Name          Size      Address         Type
# ZERO-NEXT:   0               00000000 0000000000000000
# ZERO-NEXT:   1 .aaa          00000008 0000000000000123 DATA

## Check that ALIGN zero do nothing and does not crash #2.
# RUN: echo "SECTIONS { . = 0x123; . = ALIGN(0); .aaa : { *(.aaa) } }" > %t.script
# RUN: ld.lld -o %t5 --script %t.script %t
# RUN: llvm-objdump -section-headers %t5 | FileCheck %s -check-prefix=ZERO

## Test we fail gracefuly when alignment value is not a power of 2 (#1).
# RUN: echo "SECTIONS { . = 0x123; . = ALIGN(0x123, 3); .aaa : { *(.aaa) } }" > %t.script
# RUN: not ld.lld -o %t6 --script %t.script %t 2>&1 | FileCheck -check-prefix=ERR %s
# ERR: {{.*}}.script:1: alignment must be power of 2

## Test we fail gracefuly when alignment value is not a power of 2 (#2).
# RUN: echo "SECTIONS { . = 0x123; . = ALIGN(3); .aaa : { *(.aaa) } }" > %t.script
# RUN: not ld.lld -o %t7 --script %t.script %t 2>&1 | FileCheck -check-prefix=ERR %s

# RUN: echo "SECTIONS {                              \
# RUN:  . = 0xff8;                                   \
# RUN:  .aaa : {                                     \
# RUN:           *(.aaa)                             \
# RUN:           foo = ALIGN(., 0x100);              \
# RUN:           bar = .;                            \
# RUN:           zed1 = ALIGN(., 0x100) + 1;         \
# RUN:           zed2 = ALIGN(., 0x100) - 1;         \
# RUN:         }                                     \
# RUN:  .bbb : { *(.bbb); }                          \
# RUN:  .ccc : { *(.ccc); }                          \
# RUN:  .text : { *(.text); }                        \
# RUN: }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck --check-prefix=OFFSET %s

# OFFSET: 0000000000001000         .aaa            00000000 foo
# OFFSET: 0000000000001000         .aaa            00000000 bar
# OFFSET: 0000000000001001         .aaa            00000000 zed1
# OFFSET: 0000000000000fff         .aaa            00000000 zed2

.global _start
_start:
 nop

.section .aaa, "a"
.quad 0

.section .bbb, "a"
.quad 0

.section .ccc, "a"
.quad 0
