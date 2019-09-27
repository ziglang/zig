# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: echo -e '.globl foo\nfoo: ret' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-pc-linux - -o %t2.o

# RUN: ld.lld -shared -o %t.so %t1.o --start-lib %t2.o
# RUN: llvm-readobj --dyn-syms %t.so | FileCheck %s

# CHECK:      Name: foo
# CHECK-NEXT: Value: 0x0
# CHECK-NEXT: Size: 0
# CHECK-NEXT: Binding: Weak
# CHECK-NEXT: Type: None
# CHECK-NEXT: Other: 0
# CHECK-NEXT: Section: Undefined

.weak foo
.data
.quad foo
