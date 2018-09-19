# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { \
# RUN:   . = SIZEOF_HEADERS; \
# RUN:   .rodata : { *(.aaa) *(.bbb) A = .; *(.ccc) B = .; } \
# RUN: }" > %t.script
# RUN: ld.lld -o %t.so --script %t.script %t.o -shared
# RUN: llvm-readobj --dyn-symbols %t.so | FileCheck %s

# CHECK:      DynamicSymbols [
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name:
# CHECK-NEXT:     Value:
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding:
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section:
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: A
# CHECK-NEXT:     Value: 0x226
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding:
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section:
# CHECK-NEXT:   }
# CHECK-NEXT:   Symbol {
# CHECK-NEXT:     Name: B
# CHECK-NEXT:     Value: 0x227
# CHECK-NEXT:     Size:
# CHECK-NEXT:     Binding:
# CHECK-NEXT:     Type:
# CHECK-NEXT:     Other:
# CHECK-NEXT:     Section:
# CHECK-NEXT:   }
# CHECK-NEXT: ]


.section .aaa,"a"
.byte 11

.section .bbb,"aMS",@progbits,1
.asciz "foo"

.section .ccc,"a"
.byte 33
