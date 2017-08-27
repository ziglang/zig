# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:                  .text : { \
# RUN:                    bar1 = ALIGNOF(.text); \
# RUN:                    bar2 = CONSTANT (MAXPAGESIZE); \
# RUN:                    bar3 = SIZEOF (.text); \
# RUN:                    bar4 = SIZEOF_HEADERS; \
# RUN:                    bar5 = 0x42; \
# RUN:                    bar6 = foo + 1; \
# RUN:                    *(.text) \
# RUN:                  } \
# RUN:                };" > %t.script
# RUN: ld.lld -o %t.so --script %t.script %t.o -shared
# RUN: llvm-readobj -t %t.so | FileCheck %s

.global foo
foo = 0x123

# CHECK:      Symbol {
# CHECK:        Name: foo
# CHECK-NEXT:   Value: 0x123
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute (0xFFF1)
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: bar1
# CHECK-NEXT:   Value: 0x4
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: bar2
# CHECK-NEXT:   Value: 0x1000
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: bar3
# CHECK-NEXT:   Value: 0x0
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: bar4
# CHECK-NEXT:   Value: 0x190
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: bar5
# CHECK-NEXT:   Value: 0x42
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global
# CHECK-NEXT:   Type: None
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute
# CHECK-NEXT: }
# CHECK-NEXT: Symbol {
# CHECK-NEXT:   Name: bar6
# CHECK-NEXT:   Value: 0x124
# CHECK-NEXT:   Size: 0
# CHECK-NEXT:   Binding: Global (0x1)
# CHECK-NEXT:   Type: None (0x0)
# CHECK-NEXT:   Other: 0
# CHECK-NEXT:   Section: Absolute (0xFFF1)
# CHECK-NEXT: }
