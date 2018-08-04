# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

## Check we are able to find a function symbol that encloses
## a given location when reporting error messages.
# CHECK: {{.*}}.o:(function func): relocation R_X86_64_32S out of range: -281474974609408 is not in [-2147483648, 2147483647]

.section .text.func, "ax", %progbits
.globl func
.type func,@function
.size func, 0x10
func:
 movq func - 0x1000000000000, %rdx
