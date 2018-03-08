; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: echo "foo = bar;" > %t.script

; RUN: ld.lld -m elf_x86_64 %t.o -o %t2 --script %t.script -save-temps
; RUN: llvm-readobj -symbols %t2.lto.o | FileCheck %s

; CHECK-NOT:  zed
; CHECK:      Symbol {
; CHECK:        Name: bar
; CHECK-NEXT:   Value:
; CHECK-NEXT:   Size:
; CHECK-NEXT:   Binding: Global
; CHECK-NEXT:   Type: Function
; CHECK-NEXT:   Other:
; CHECK-NEXT:   Section:
; CHECK-NEXT: }
; CHECK-NOT:  zed

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @bar() {
  ret void
}

define void @zed() {
  ret void
}
