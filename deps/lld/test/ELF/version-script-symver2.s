# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "VER1 { global: foo; local: *; }; VER2 { global: foo; }; VER3 { global: foo; };" > %t.map
# RUN: ld.lld -shared %t.o --version-script %t.map -o %t.so --fatal-warnings
# RUN: llvm-readobj -V %t.so | FileCheck %s

# CHECK:      Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 0
# CHECK-NEXT:     Name: @
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 3
# CHECK-NEXT:     Name: foo@@VER2
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Version: 2
# CHECK-NEXT:     Name: foo@VER1
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.global bar
bar:
.symver bar, foo@VER1

.global zed
zed:
.symver zed, foo@@VER2
