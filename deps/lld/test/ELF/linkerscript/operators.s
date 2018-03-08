# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: echo "SECTIONS { \
# RUN:  _start = .; \
# RUN:  plus = 1 + 2 + 3; \
# RUN:  minus = 5 - 1; \
# RUN:  div = 6 / 2; \
# RUN:  mul = 1 + 2 * 3; \
# RUN:  nospace = 1+2*6/3; \
# RUN:  braces = 1 + (2 + 3) * 4; \
# RUN:  and = 0xbb & 0xee; \
# RUN:  ternary1 = 1 ? 1 : 2; \
# RUN:  ternary2 = 0 ? 1 : 2; \
# RUN:  less = 1 < 0 ? 1 : 2; \
# RUN:  lesseq = 1 <= 1 ? 1 : 2; \
# RUN:  greater = 0 > 1 ? 1 : 2; \
# RUN:  greatereq = 1 >= 1 ? 1 : 2; \
# RUN:  eq = 1 == 1 ? 1 : 2; \
# RUN:  neq = 1 != 1 ? 1 : 2; \
# RUN:  plusassign = 1; \
# RUN:  plusassign += 2; \
# RUN:  unary = -1 + 3; \
# RUN:  lshift = 1 << 5; \
# RUN:  rshift = 0xff >> 3; \
# RUN:  maxpagesize = CONSTANT (MAXPAGESIZE); \
# RUN:  commonpagesize = CONSTANT (COMMONPAGESIZE); \
# RUN:  . = 0xfff0; \
# RUN:  datasegmentalign = DATA_SEGMENT_ALIGN (0xffff, 0); \
# RUN:  datasegmentalign2 = DATA_SEGMENT_ALIGN (0, 0); \
# RUN:  _end = .; \
# RUN:  minus_rel = _end - 0x10; \
# RUN:  minus_abs = _end - _start; \
# RUN: }" > %t.script
# RUN: ld.lld %t --script %t.script -o %t2
# RUN: llvm-objdump -t %t2 | FileCheck %s

# CHECK: 00000000000006 *ABS* 00000000 plus
# CHECK: 00000000000004 *ABS* 00000000 minus
# CHECK: 00000000000003 *ABS* 00000000 div
# CHECK: 00000000000007 *ABS* 00000000 mul
# CHECK: 00000000000005 *ABS* 00000000 nospace
# CHECK: 00000000000015 *ABS* 00000000 braces
# CHECK: 000000000000aa *ABS* 00000000 and
# CHECK: 00000000000001 *ABS* 00000000 ternary1
# CHECK: 00000000000002 *ABS* 00000000 ternary2
# CHECK: 00000000000002 *ABS* 00000000 less
# CHECK: 00000000000001 *ABS* 00000000 lesseq
# CHECK: 00000000000002 *ABS* 00000000 greater
# CHECK: 00000000000001 *ABS* 00000000 greatereq
# CHECK: 00000000000001 *ABS* 00000000 eq
# CHECK: 00000000000002 *ABS* 00000000 neq
# CHECK: 00000000000003 *ABS* 00000000 plusassign
# CHECK: 00000000000002 *ABS* 00000000 unary
# CHECK: 00000000000020 *ABS* 00000000 lshift
# CHECK: 0000000000001f *ABS* 00000000 rshift
# CHECK: 00000000001000 *ABS* 00000000 maxpagesize
# CHECK: 00000000001000 *ABS* 00000000 commonpagesize
# CHECK: 0000000000ffff *ABS* 00000000 datasegmentalign
# CHECK: 0000000000fff0 *ABS* 00000000 datasegmentalign2
# CHECK: 0000000000ffe0 .text 00000000 minus_rel
# CHECK: 0000000000fff0 *ABS* 00000000 minus_abs

## Mailformed number error.
# RUN: echo "SECTIONS { . = 0x12Q41; }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=NUMERR %s
# NUMERR: malformed number: 0x12Q41

## Missing closing bracket.
# RUN: echo "SECTIONS { . = (1; }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=BRACKETERR %s
# BRACKETERR: ) expected, but got ;

## Missing opening bracket.
# RUN: echo "SECTIONS { . = 1); }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=BRACKETERR2 %s
# BRACKETERR2: ; expected, but got )

## Empty expression.
# RUN: echo "SECTIONS { . = ; }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=ERREXPR %s
# ERREXPR: malformed number: ;

## Div by zero error.
# RUN: echo "SECTIONS { . = 1 / 0; }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=DIVZERO %s
# DIVZERO: division by zero

## Broken ternary operator expression.
# RUN: echo "SECTIONS { . = 1 ? 2; }" > %t.script
# RUN: not ld.lld %t --script %t.script -o %t2 2>&1 | \
# RUN:  FileCheck --check-prefix=TERNERR %s
# TERNERR: : expected, but got ;

.globl _start
_start:
nop
