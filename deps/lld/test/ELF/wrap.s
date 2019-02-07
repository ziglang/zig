// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/wrap.s -o %t2

// RUN: ld.lld -o %t3 %t %t2 -wrap foo -wrap nosuchsym
// RUN: llvm-objdump -d -print-imm-hex %t3 | FileCheck %s
// RUN: ld.lld -o %t3 %t %t2 --wrap foo -wrap=nosuchsym
// RUN: llvm-objdump -d -print-imm-hex %t3 | FileCheck %s
// RUN: ld.lld -o %t3 %t %t2 --wrap foo --wrap foo -wrap=nosuchsym
// RUN: llvm-objdump -d -print-imm-hex %t3 | FileCheck %s

// CHECK: _start:
// CHECK-NEXT: movl $0x11010, %edx
// CHECK-NEXT: movl $0x11010, %edx
// CHECK-NEXT: movl $0x11000, %edx

// RUN: llvm-readobj -t %t3 > %t4.dump
// RUN: FileCheck --check-prefix=SYM1 %s < %t4.dump
// RUN: FileCheck --check-prefix=SYM2 %s < %t4.dump
// RUN: FileCheck --check-prefix=SYM3 %s < %t4.dump

// SYM1:      Name: foo
// SYM1-NEXT: Value: 0x11000
// SYM1-NEXT: Size:
// SYM1-NEXT: Binding: Global
// SYM1-NEXT: Type:    None
// SYM1-NEXT: Other:   0
// SYM2:      Name: __wrap_foo
// SYM2-NEXT: Value: 0x11010
// SYM2-NEXT: Size:
// SYM2-NEXT: Binding: Weak
// SYM2-NEXT: Type:    None
// SYM2-NEXT: Other [
// SYM2-NEXT:   STV_PROTECTED
// SYM2-NEXT: ]
// SYM3:      Name: __real_foo
// SYM3-NEXT: Value: 0x11000
// SYM3-NEXT: Size:
// SYM3-NEXT: Binding: Global
// SYM3-NEXT: Type:    None
// SYM3-NEXT: Other:   0

.global _start
_start:
  movl $foo, %edx
  movl $__wrap_foo, %edx
  movl $__real_foo, %edx
