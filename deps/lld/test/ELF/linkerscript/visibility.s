# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { foo = .; }" > %t1.script
# RUN: ld.lld -o %t1 --script %t1.script %t.o -shared
# RUN: llvm-readobj --symbols %t1 | FileCheck %s

# CHECK:      Symbol {
# CHECK:        Name: foo
# CHECK-NEXT:   Value:
# CHECK-NEXT:   Size:
# CHECK-NEXT:   Binding: Local
# CHECK-NEXT:   Type:
# CHECK-NEXT:   Other [
# CHECK-NEXT:     STV_HIDDEN
# CHECK-NEXT:   ]
# CHECK-NEXT:   Section:
# CHECK-NEXT: }

        .data
        .hidden foo
        .quad foo
