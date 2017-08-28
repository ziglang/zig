# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { }" > %t.script
# RUN: ld.lld %t.o -script %t.script -o %t
# RUN: llvm-readobj -symbols %t | FileCheck %s
# CHECK:    Name: __ehdr_start (1)
# CHECK-NEXT:    Value: 0x0
# CHECK-NEXT:    Size: 0
# CHECK-NEXT:    Binding: Local (0x0)
# CHECK-NEXT:    Type: None (0x0)
# CHECK-NEXT:    Other [ (0x2)
# CHECK-NEXT:      STV_HIDDEN (0x2)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Section: .text (0x1)

.text
.global _start, __ehdr_start
_start:
	.quad __ehdr_start
