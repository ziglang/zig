; REQUIRES: x86
; RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -o %t.o %p/Inputs/dynsym.s
; RUN: ld.lld -m elf_x86_64 %t.o -o %t.so -shared
; RUN: llvm-as %s -o %t2.o
; RUN: ld.lld -m elf_x86_64 %t2.o %t.so -o %t
; RUN: llvm-readobj -dyn-symbols %t | FileCheck %s

; Check that we don't crash when gc'ing sections and printing the result.
; RUN: ld.lld -m elf_x86_64 %t2.o %t.so --gc-sections --print-gc-sections \
; RUN:   -o %t
; RUN: llvm-readobj -dyn-symbols %t | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @_start() {
  call void @foo()
  ret void
}

; CHECK:      Name: foo
; CHECK-NEXT: Value:
; CHECK-NEXT: Size:
; CHECK-NEXT: Binding:
; CHECK-NEXT: Type:
; CHECK-NEXT: Other:
; CHECK-NEXT: Section: .text
define void @foo() {
  ret void
}
