# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: ld.lld %t.o -o %t1.exe
# RUN: llvm-readobj -sections %t1.exe | FileCheck %s
# CHECK: .debug_gnu_pubnames
# CHECK: .debug_gnu_pubtypes

# RUN: ld.lld -gdb-index %t.o -o %t2.exe
# RUN: llvm-readobj -sections %t2.exe | FileCheck %s --check-prefix=GDB
# GDB-NOT: .debug_gnu_pubnames
# GDB-NOT: .debug_gnu_pubtypes

.section .debug_gnu_pubnames,"",@progbits
.long 0

.section .debug_gnu_pubtypes,"",@progbits
.long 0
