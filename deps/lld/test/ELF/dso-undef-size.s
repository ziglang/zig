# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/dso-undef-size.s -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t1.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t2.o
# RUN: ld.lld -shared %t2.o %t1.so -o %t2.so
# RUN: llvm-readobj --symbols --dyn-syms %t2.so

# CHECK:      Symbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: foo
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding:
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: foo
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size: 0
# CHECK-NEXT:     Binding:
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT: ]

.text
.global foo
