# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux-gnu %s -o %t.o

# Without --warn-text-ifunc, lld should run fine:
# RUN: ld.lld -z notext %t.o -o %t2

# With --warn-text-ifunc, lld should run with warnings:
# RUN: ld.lld --warn-ifunc-textrel -z notext %t.o -o /dev/null 2>&1 | FileCheck %s
# CHECK: using ifunc symbols when text relocations are allowed may produce
# CHECK-SAME: a binary that will segfault, if the object file is linked with
# CHECK-SAME: old version of glibc (glibc 2.28 and earlier). If this applies to
# CHECK-SAME: you, consider recompiling the object files without -fPIC and
# CHECK-SAME: without -Wl,-z,notext option. Use -no-warn-ifunc-textrel to
# CHECK-SAME: turn off this warning.
# CHECK: >>> defined in {{.*}}
# CHECK: >>> referenced by {{.*}}:(.text+0x8)

# Without text relocations, lld should run fine:
# RUN: ld.lld --fatal-warnings %t.o -o /dev/null

.text
.globl a_func_impl
a_func_impl:
  nop

.globl selector
.type selector,@function
selector:
  movl $a_func_impl, %eax
  retq

.globl a_func
.type a_func,@gnu_indirect_function
.set a_func, selector

.globl _start
.type _start,@function
main:
  callq a_func
  retq
