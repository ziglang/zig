# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/warn-common.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/warn-common2.s -o %t3.o

## Report multiple commons if warn-common is specified
# RUN: ld.lld --warn-common %t1.o %t2.o -o %t.out 2>&1 | FileCheck %s --check-prefix=WARN
# WARN: multiple common of arr

## no-warn-common is ignored
# RUN: ld.lld --no-warn-common %t1.o %t2.o -o %t.out
# RUN: llvm-readobj %t.out > /dev/null

## Report if common is overridden
# RUN: ld.lld --warn-common %t1.o %t3.o -o %t.out 2>&1 | FileCheck %s --check-prefix=OVER
# OVER: common arr is overridden

## Report if common is overridden, but in different order
# RUN: ld.lld --warn-common %t3.o %t1.o -o %t.out 2>&1 | FileCheck %s --check-prefix=OVER

.globl _start
_start:

.type arr,@object
.comm arr,4,4
