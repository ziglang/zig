# RUN: llvm-mc -triple=mips64-unknown-freebsd %s -filetype=obj -o %t.o
# RUN: not ld.lld %t.o %S/Inputs/corrupt-version-reference.so -o %t.exe 2>&1 | FileCheck %s
# REQUIRES: mips

# CHECK: error: corrupt input file: version definition index 9 for symbol __cxa_finalize is out of bounds
# CHECK: >>> defined in {{.+}}/corrupt-version-reference.so

# CHECK:      error: corrupt input file: version definition index 0 for symbol _Jv_RegisterClasses is out of bounds
# CHECK-NEXT: >>> defined in {{.*}}/corrupt-version-reference.so

.globl __start
__start:
    dla $a0, __cxa_finalize
    nop
