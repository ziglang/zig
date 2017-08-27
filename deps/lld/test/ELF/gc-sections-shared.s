# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --gc-sections --export-dynamic-symbol foo -o %t %t.o --as-needed %t2.so
# RUN: llvm-readobj --dynamic-table --dyn-symbols %t | FileCheck %s

# This test the property that we have a needed line for every undefined.
# It would also be OK to drop bar2 and the need for the .so

# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Local
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: Undefined (0x0)
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: bar2
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: foo
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK: NEEDED Shared library: [{{.*}}.so]

.section .text.foo, "ax"
.globl foo
foo:
call bar

.section .text.bar, "ax"
.globl bar
bar:
ret

.section .text._start, "ax"
.globl _start
_start:
ret

.section .text.unused, "ax"
call bar2
