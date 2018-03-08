# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %ta.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux -o %t.o < /dev/null
# RUN: rm -f %tar.a
# RUN: llvm-ar rcs %tar.a %ta.o

# RUN: echo "SECTIONS { foo = 1; }" > %t1.script
# RUN: ld.lld -o %t1.exe --script %t1.script %tar.a %t.o
# RUN: llvm-readobj -symbols %t1.exe | FileCheck %s
# CHECK-NOT: bar
# CHECK:     foo
# CHECK-NOT: bar

# RUN: echo "SECTIONS { zed = foo; }" > %t2.script
# RUN: ld.lld -o %t2.exe --script %t2.script %tar.a %t.o
# RUN: llvm-readobj -symbols %t2.exe | FileCheck %s --check-prefix=SYMS
# SYMS: bar
# SYMS: foo

.text
.globl foo
foo:
 nop

.globl bar
bar:
 nop
