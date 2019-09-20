; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t2
; RUN: llvm-readobj --symbols %t2 | FileCheck %s

; CHECK:      Format: ELF64-x86-64
; CHECK-NEXT: Arch: x86_64
; CHECK-NEXT: AddressSize: 64bit

; CHECK:      Name: _start
; CHECK-NEXT: Value:
; CHECK-NEXT: Size: 1
; CHECK-NEXT: Binding: Global
; CHECK-NEXT: Type: Function
; CHECK-NEXT: Other:
; CHECK-NEXT: Section: .text

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @_start() {
  ret void
}
