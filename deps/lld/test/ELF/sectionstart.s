# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o --section-start .text=0x100000 \
# RUN:   --section-start .data=0x110000 --section-start .bss=0x200000 -o %t
# RUN: llvm-objdump -section-headers %t | FileCheck %s

# CHECK:      Sections:
# CHECK-NEXT:  Idx Name          Size      Address          Type
# CHECK-NEXT:    0               00000000 0000000000000000
# CHECK-NEXT:    1 .text         00000001 0000000000100000 TEXT DATA
# CHECK-NEXT:    2 .data         00000004 0000000000110000 DATA
# CHECK-NEXT:    3 .bss          00000004 0000000000200000 BSS

## The same, but dropped "0x" prefix.
# RUN: ld.lld %t.o --section-start .text=100000 \
# RUN:   --section-start .data=110000 --section-start .bss=0x200000 -o %t1
# RUN: llvm-objdump -section-headers %t1 | FileCheck %s

## Use -Ttext, -Tdata, -Tbss as replacement for --section-start:
# RUN: ld.lld %t.o -Ttext=0x100000 -Tdata=0x110000 -Tbss=0x200000 -o %t4
# RUN: llvm-objdump -section-headers %t4 | FileCheck %s

## Check Ttext-segment X and Ttext-segment=X forms.
# RUN: ld.lld %t.o -Ttext-segment=0x100000 -Tdata=0x110000 -Tbss=0x200000 -o %t4
# RUN: llvm-objdump -section-headers %t4 | FileCheck %s
# RUN: ld.lld %t.o -Ttext-segment 0x100000 -Tdata=0x110000 -Tbss=0x200000 -o %t4
# RUN: llvm-objdump -section-headers %t4 | FileCheck %s

## The same, but dropped "0x" prefix.
# RUN: ld.lld %t.o -Ttext=100000 -Tdata=110000 -Tbss=200000 -o %t5
# RUN: llvm-objdump -section-headers %t5 | FileCheck %s

## Check form without assignment:
# RUN: ld.lld %t.o -Ttext 0x100000 -Tdata 0x110000 -Tbss 0x200000 -o %t4
# RUN: llvm-objdump -section-headers %t4 | FileCheck %s

## Errors:
# RUN: not ld.lld %t.o --section-start .text100000 -o %t2 2>&1 \
# RUN:    | FileCheck -check-prefix=ERR1 %s
# ERR1: invalid argument: --section-start .text100000

# RUN: not ld.lld %t.o --section-start .text=1Q0000 -o %t3 2>&1 \
# RUN:    | FileCheck -check-prefix=ERR2 %s
# ERR2: invalid argument: --section-start .text=1Q0000

# RUN: not ld.lld %t.o -Ttext=1w0000 -o %t6 2>&1 \
# RUN:    | FileCheck -check-prefix=ERR3 %s
# ERR3: invalid argument: --Ttext 1w0000

# RUN: not ld.lld %t.o -Tbss=1w0000 -o %t6 2>&1 \
# RUN:    | FileCheck -check-prefix=ERR4 %s
# ERR4: invalid argument: --Tbss 1w0000

# RUN: not ld.lld %t.o -Tdata=1w0000 -o %t6 2>&1 \
# RUN:    | FileCheck -check-prefix=ERR5 %s
# ERR5: invalid argument: --Tdata 1w0000

.text
.globl _start
_start:
 nop

.data
.long 0

.bss
.zero 4
