# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN:   %p/Inputs/allow-shlib-undefined.s -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t.so

# RUN: ld.lld --allow-shlib-undefined %t.o %t.so -o /dev/null
# RUN: not ld.lld --no-allow-shlib-undefined %t.o %t.so -o /dev/null 2>&1 | FileCheck %s
# Executable defaults to --no-allow-shlib-undefined
# RUN: not ld.lld %t.o %t.so -o /dev/null 2>&1 | FileCheck %s
# -shared defaults to --allow-shlib-undefined
# RUN: ld.lld -shared %t.o %t.so -o /dev/null

# RUN: echo | llvm-mc -filetype=obj -triple=x86_64-unknown-linux -o %tempty.o
# RUN: ld.lld -shared %tempty.o -o %tempty.so
# RUN: ld.lld -shared %t1.o %tempty.so -o %t2.so
# RUN: ld.lld --no-allow-shlib-undefined %t.o %t2.so -o /dev/null

# DSO with undefines:
# should link with or without any of these options.
# RUN: ld.lld -shared %t1.o -o /dev/null
# RUN: ld.lld -shared --allow-shlib-undefined %t1.o -o /dev/null
# RUN: ld.lld -shared --no-allow-shlib-undefined %t1.o -o /dev/null

.globl _start
_start:
  callq _shared@PLT

# CHECK: undefined reference to _unresolved
