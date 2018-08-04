# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/warn-common.s -o %t2.o

# RUN: ld.lld --warn-common %t1.o %t2.o -o /dev/null 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR %s
# ERR: multiple common of

# RUN: not ld.lld --warn-common --fatal-warnings %t1.o %t2.o -o /dev/null 2>&1 | \
# RUN:   FileCheck -check-prefix=ERR %s

.globl _start
_start:

.type arr,@object
.comm arr,4,4
