# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %p/Inputs/aarch64-addrifunc.s -o %t1.o

# RUN: ld.lld --shared %t1.o -o %t1.so
# RUN: ld.lld --pie %t1.so %t.o -o %t
# RUN: llvm-objdump -d -mattr=+bti -triple=aarch64-linux-gnu %t | FileCheck %s

# When the address of an ifunc is taken using a non-got reference which clang
# can do, LLD exports a canonical PLT entry that may have its address taken so
# we must use bti c.

# CHECK: Disassembly of section .plt:
# CHECK: 0000000000010020 .plt:
# CHECK-NEXT:    10020: 5f 24 03 d5                     bti     c
# CHECK-NEXT:    10024: f0 7b bf a9                     stp     x16, x30, [sp, #-16]!
# CHECK-NEXT:    10028: 10 01 00 90                     adrp    x16, #131072
# CHECK-NEXT:    1002c: 11 0a 40 f9                     ldr     x17, [x16, #16]
# CHECK-NEXT:    10030: 10 42 00 91                     add     x16, x16, #16
# CHECK-NEXT:    10034: 20 02 1f d6                     br      x17
# CHECK-NEXT:    10038: 1f 20 03 d5                     nop
# CHECK-NEXT:    1003c: 1f 20 03 d5                     nop
# CHECK: 0000000000010040 func1@plt:
# CHECK-NEXT:    10040: 5f 24 03 d5                     bti     c
# CHECK-NEXT:    10044: 10 01 00 90                     adrp    x16, #131072
# CHECK-NEXT:    10048: 11 0e 40 f9                     ldr     x17, [x16, #24]
# CHECK-NEXT:    1004c: 10 62 00 91                     add     x16, x16, #24
# CHECK-NEXT:    10050: 20 02 1f d6                     br      x17
# CHECK-NEXT:    10054: 1f 20 03 d5                     nop
# CHECK-NEXT:           ...
# CHECK: 0000000000010060 myfunc:
# CHECK-NEXT:    10060: 5f 24 03 d5                     bti     c
# CHECK-NEXT:    10064: 10 01 00 90                     adrp    x16, #131072
# CHECK-NEXT:    10068: 11 12 40 f9                     ldr     x17, [x16, #32]
# CHECK-NEXT:    1006c: 10 82 00 91                     add     x16, x16, #32
# CHECK-NEXT:    10070: 20 02 1f d6                     br      x17
# CHECK-NEXT:    10074: 1f 20 03 d5                     nop

.section ".note.gnu.property", "a"
.long 4
.long 0x10
.long 0x5
.asciz "GNU"

.long 0xc0000000 // GNU_PROPERTY_AARCH64_FEATURE_1_AND
.long 4
.long 1          // GNU_PROPERTY_AARCH64_FEATURE_1_BTI
.long 0

.text
.globl myfunc
.type myfunc,@gnu_indirect_function
myfunc:
 ret

.globl func1

.text
.globl _start
.type _start, %function
_start:
  bl func1
  adrp x8, myfunc
  add x8, x8, :lo12:myfunc
  ret
