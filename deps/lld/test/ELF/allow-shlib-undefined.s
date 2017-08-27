# REQUIRES: x86
# --allow-shlib-undefined and --no-allow-shlib-undefined are fully
# ignored in linker implementation.
# --allow-shlib-undefined is set by default
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux \
# RUN: %p/Inputs/allow-shlib-undefined.s -o %t
# RUN: ld.lld -shared %t -o %t.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1

# Executable: should link with DSO containing undefined symbols in any case.
# RUN: ld.lld %t1 %t.so -o %t2
# RUN: ld.lld --no-allow-shlib-undefined %t1 %t.so -o %t2
# RUN: ld.lld --allow-shlib-undefined %t1 %t.so -o %t2

# DSO with undefines:
# should link with or without any of these options.
# RUN: ld.lld -shared %t -o %t.so
# RUN: ld.lld -shared --allow-shlib-undefined %t -o %t.so
# RUN: ld.lld -shared --no-allow-shlib-undefined %t -o %t.so

# Executable still should not link when have undefines inside.
# RUN: not ld.lld %t -o %t.so

.globl _start
_start:
  callq _shared@PLT
