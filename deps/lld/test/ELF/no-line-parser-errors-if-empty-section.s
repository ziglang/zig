# REQUIRES: x86

# LLD uses the debug data to get information for error messages, if possible.
# However, if the debug line section is empty, we should not attempt to parse
# it, as that would result in errors from the parser.

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK-NOT: warning:
# CHECK-NOT: error:
# CHECK: error: undefined symbol: undefined
# CHECK-NEXT: {{.*}}.o:(.text+0x1)
# CHECK-NOT: warning:
# CHECK-NOT: error:

.globl _start
_start:
    callq undefined

.section .debug_line,"",@progbits
