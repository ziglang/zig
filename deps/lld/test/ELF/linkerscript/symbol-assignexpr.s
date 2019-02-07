# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { \
# RUN:         symbol = CONSTANT(MAXPAGESIZE); \
# RUN:         symbol2 = symbol + 0x1234; \
# RUN:         symbol3 = symbol2; \
# RUN:         symbol4 = symbol + -4; \
# RUN:         symbol5 = symbol - ~0xfffb; \
# RUN:         symbol6 = symbol - ~(0xfff0 + 0xb); \
# RUN:         symbol7 = symbol - ~ 0xfffb + 4; \
# RUN:         symbol8 = ~ 0xffff + 4; \
# RUN:         symbol9 = - 4; \
# RUN:         symbol10 = 0xfedcba9876543210; \
# RUN:         symbol11 = ((0x28000 + 0x1fff) & ~(0x1000 + -1)); \
# RUN:         symbol12 = 0x1234; \
# RUN:         symbol12 += 1; \
# RUN:         symbol13 = !1; \
# RUN:         symbol14 = !0; \
# RUN:         symbol15 = 0!=1; \
# RUN:         bar = 0x5678; \
# RUN:         baz = 0x9abc; \
# RUN:       }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-objdump -t %t1 | FileCheck %s

# CHECK:      SYMBOL TABLE:
# CHECK-NEXT: 0000000000000000 .text 00000000 _start
# CHECK-NEXT: 0000000000005678 *ABS* 00000000 bar
# CHECK-NEXT: 0000000000009abc *ABS* 00000000 baz
# CHECK-NEXT: 0000000000000001 .text 00000000 foo
# CHECK-NEXT: 0000000000001000 *ABS* 00000000 symbol
# CHECK-NEXT: 0000000000002234 *ABS* 00000000 symbol2
# CHECK-NEXT: 0000000000002234 *ABS* 00000000 symbol3
# CHECK-NEXT: 0000000000000ffc *ABS* 00000000 symbol4
# CHECK-NEXT: 0000000000010ffc *ABS* 00000000 symbol5
# CHECK-NEXT: 0000000000010ffc *ABS* 00000000 symbol6
# CHECK-NEXT: 0000000000011000 *ABS* 00000000 symbol7
# CHECK-NEXT: ffffffffffff0004 *ABS* 00000000 symbol8
# CHECK-NEXT: fffffffffffffffc *ABS* 00000000 symbol9
# CHECK-NEXT: fedcba9876543210 *ABS* 00000000 symbol10
# CHECK-NEXT: 0000000000029000 *ABS* 00000000 symbol11
# CHECK-NEXT: 0000000000001235 *ABS* 00000000 symbol12
# CHECK-NEXT: 0000000000000000 *ABS* 00000000 symbol13
# CHECK-NEXT: 0000000000000001 *ABS* 00000000 symbol14
# CHECK-NEXT: 0000000000000001 *ABS* 00000000 symbol15

# RUN: echo "SECTIONS { symbol2 = symbol; }" > %t2.script
# RUN: not ld.lld -o /dev/null --script %t2.script %t 2>&1 \
# RUN:  | FileCheck -check-prefix=ERR %s
# ERR: {{.*}}.script:1: symbol not found: symbol

.global _start
_start:
 nop

.global foo
foo:
 nop

.global bar
bar = 0x1234

.comm baz,8,8
