# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/shared.s -o %t2.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/gc-sections-shared.s -o %t3.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/gc-sections-shared2.s -o %t4.o
# RUN: ld.lld -shared %t2.o -o %t2.so
# RUN: ld.lld -shared %t3.o -o %t3.so
# RUN: ld.lld -shared %t4.o -o %t4.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld --gc-sections --export-dynamic-symbol foo -o %t %t.o --as-needed %t2.so %t3.so %t4.so
# RUN: llvm-readobj --dynamic-table --dyn-symbols %t | FileCheck %s

# This test the property that we have a needed line for every undefined.
# It would also be OK to keep bar2 and the need for %t2.so
# At the same time, weak symbols should not cause adding DT_NEEDED;
# this case is checked with symbol qux and %t4.so.

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
# CHECK-NEXT:     Name: bar
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Global
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: .text
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: baz
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
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: qux
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding: Weak
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:   }
# CHECK-NEXT: ]

# CHECK-NOT: NEEDED
# CHECK:     NEEDED Shared library: [{{.*}}3.so]
# CHECK-NOT: NEEDED

# Test with %t.o at the end too.
# RUN: ld.lld --gc-sections --export-dynamic-symbol foo -o %t --as-needed %t2.so %t3.so %t4.so %t.o
# RUN: llvm-readobj --dynamic-table --dyn-symbols %t | FileCheck --check-prefix=CHECK2 %s

# CHECK2:      DynamicSymbols [
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name:
# CHECK2-NEXT:     Value:
# CHECK2-NEXT:     Size:
# CHECK2-NEXT:     Binding: Local
# CHECK2-NEXT:     Type:
# CHECK2-NEXT:     Other:
# CHECK2-NEXT:     Section: Undefined (0x0)
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: bar
# CHECK2-NEXT:     Value:
# CHECK2-NEXT:     Size:
# CHECK2-NEXT:     Binding: Global
# CHECK2-NEXT:     Type:
# CHECK2-NEXT:     Other:
# CHECK2-NEXT:     Section: .text
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: baz
# CHECK2-NEXT:     Value:
# CHECK2-NEXT:     Size:
# CHECK2-NEXT:     Binding: Global
# CHECK2-NEXT:     Type:
# CHECK2-NEXT:     Other:
# CHECK2-NEXT:     Section: Undefined
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: qux
# CHECK2-NEXT:     Value:
# CHECK2-NEXT:     Size:
# CHECK2-NEXT:     Binding: Weak
# CHECK2-NEXT:     Type:
# CHECK2-NEXT:     Other:
# CHECK2-NEXT:     Section: Undefined
# CHECK2-NEXT:   }
# CHECK2-NEXT:   Symbol {
# CHECK2-NEXT:     Name: foo
# CHECK2-NEXT:     Value:
# CHECK2-NEXT:     Size:
# CHECK2-NEXT:     Binding: Global
# CHECK2-NEXT:     Type:
# CHECK2-NEXT:     Other:
# CHECK2-NEXT:     Section: .text
# CHECK2-NEXT:   }
# CHECK2-NEXT: ]

# CHECK2-NOT: NEEDED
# CHECK2:     NEEDED Shared library: [{{.*}}3.so]
# CHECK2-NOT: NEEDED

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
.weak qux
_start:
call baz
call qux
ret

.section .text.unused, "ax"
call bar2
