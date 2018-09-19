# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "FOO { global: extern \"C++\" { \"abb(int)\"; }; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s

# CHECK:      Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 0
# CHECK-NEXT:     Name: @
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 1
# CHECK-NEXT:     Name: _Z3abbi@
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.globl _Z3abbi
