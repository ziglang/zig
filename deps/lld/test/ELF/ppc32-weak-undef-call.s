# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=EXE %s
# RUN: ld.lld -pie %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=EXE %s
# RUN: ld.lld -shared %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=SHARED %s

## It does not really matter how we fixup it, but we cannot overflow and
## should not generate a call stub (this would waste space).
# EXE: bl .+0

## With -shared, create a call stub. ld.bfd produces bl .+0
# SHARED: bl .+4
# SHARED: 00000000.plt_pic32.foo:

.weak foo
bl foo
