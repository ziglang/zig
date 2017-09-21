# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t
# RUN: llvm-readobj -symbols %t | FileCheck %s
# CHECK:    Name: __dso_handle
# CHECK-NEXT:    Value: 0x0
# CHECK-NEXT:    Size: 0
# CHECK-NEXT:    Binding: Local
# CHECK-NEXT:    Type: None
# CHECK-NEXT:    Other [
# CHECK-NEXT:      STV_HIDDEN
# CHECK-NEXT:    ]
# CHECK-NEXT:    Section: .dynsym

.text
.global foo, __dso_handle
foo:
  lea __dso_handle(%rip),%rax
