# REQUIRES: x86

# We used to crash on this
# RUN: ld.lld %p/Inputs/local-symbol-in-dso.so -o %t 2>&1 | \
# RUN:   FileCheck -check-prefix=WARN %s
# WARN: found local symbol 'foo' in global part of symbol table in file {{.*}}local-symbol-in-dso.so

# RUN: llvm-mc %s -o %t.o -filetype=obj -triple x86_64-pc-linux
# RUN: not ld.lld %t.o %p/Inputs/local-symbol-in-dso.so -o %t

.globl main
main:
  movq foo@GOTTPOFF(%rip), %rax
