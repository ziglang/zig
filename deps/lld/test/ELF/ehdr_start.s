# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj -symbols %t | FileCheck %s
# CHECK:    Name: __ehdr_start (1)
# CHECK-NEXT:    Value: 0x200000
# CHECK-NEXT:    Size: 0
# CHECK-NEXT:    Binding: Local (0x0)
# CHECK-NEXT:    Type: None (0x0)
# CHECK-NEXT:    Other [ (0x2)
# CHECK-NEXT:      STV_HIDDEN (0x2)
# CHECK-NEXT:    ]
# CHECK-NEXT:    Section: .text (0x1)

# CHECK:    Name: __executable_start
# CHECK-NEXT:    Value: 0x200000
# CHECK-NEXT:    Size: 0
# CHECK-NEXT:    Binding: Local
# CHECK-NEXT:    Type: None
# CHECK-NEXT:    Other [
# CHECK-NEXT:      STV_HIDDEN
# CHECK-NEXT:    ]
# CHECK-NEXT:    Section: .text

.text
.global _start, __ehdr_start
_start:
  .quad __ehdr_start
  .quad __executable_start

# RUN: ld.lld -r %t.o -o %t.r
# RUN: llvm-readobj -symbols %t.r | FileCheck %s --check-prefix=RELOCATABLE

# RELOCATABLE:    Name: __ehdr_start (1)
# RELOCATABLE-NEXT:    Value: 0x0
# RELOCATABLE-NEXT:    Size: 0
# RELOCATABLE-NEXT:    Binding: Global (0x1)
# RELOCATABLE-NEXT:    Type: None (0x0)
# RELOCATABLE-NEXT:    Other: 0
# RELOCATABLE-NEXT:    Section: Undefined (0x0)
