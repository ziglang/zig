# REQUIRES: x86
# RUN: mkdir -p %t.dir
# RUN: cd %t.dir
# RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
# RUN: ld.lld %t.o -o t.so -shared -version-script %p/Inputs/empty-ver.ver
# RUN: llvm-readobj --version-info t.so | FileCheck %s

# CHECK:       Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 0
# CHECK-NEXT:     Name:
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 1
# CHECK-NEXT:     Name: bar@
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.global bar@
bar@:
