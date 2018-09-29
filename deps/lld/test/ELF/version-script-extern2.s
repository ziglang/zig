# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "FOO { global: extern \"C++\" { \"bar\"; }; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o %t.so
# RUN: llvm-readobj -V %t.so | FileCheck %s

# CHECK:      Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 0
# CHECK-NEXT:     Name: @
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 2
# CHECK-NEXT:     Name: bar@@FOO
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.globl bar
.type bar,@function
bar:
retq
