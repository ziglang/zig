# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %tso.o
# RUN: ld.lld -shared %tso.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: ld.lld -dynamic-linker foo --no-dynamic-linker %t.o %t.so -o %t
# RUN: llvm-readobj --program-headers %t | FileCheck %s --check-prefix=NODL
# NODL-NOT: PT_INTERP

# RUN: ld.lld --no-dynamic-linker -dynamic-linker foo %t.o %t.so -o %t
# RUN: llvm-readobj --program-headers %t | FileCheck %s --check-prefix=WITHDL
# WITHDL: PT_INTERP
