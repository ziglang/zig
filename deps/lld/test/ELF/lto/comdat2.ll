; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: llvm-mc -triple=x86_64-pc-linux %p/Inputs/comdat.s -o %t2.o -filetype=obj
; RUN: ld.lld %t.o %t2.o -o %t.so -shared
; RUN: llvm-readobj --symbols %t.so | FileCheck %s
; RUN: ld.lld %t2.o %t.o -o %t2.so -shared
; RUN: llvm-readobj --symbols %t2.so | FileCheck %s --check-prefix=OTHER


target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

$c = comdat any

define protected void @foo() comdat($c) {
  ret void
}

; CHECK: Symbol {
; CHECK:   Name: foo
; CHECK-NEXT:   Value: 0x1000
; CHECK-NEXT:   Size: 1
; CHECK-NEXT:   Binding: Global
; CHECK-NEXT:   Type: Function
; CHECK-NEXT:   Other [
; CHECK-NEXT:     STV_PROTECTED
; CHECK-NEXT:   ]
; CHECK-NEXT:   Section: .text
; CHECK-NEXT: }

; OTHER: Symbol {
; OTHER:   Name: foo
; OTHER-NEXT:   Value: 0x1000
; OTHER-NEXT:   Size: 0
; OTHER-NEXT:   Binding: Global
; OTHER-NEXT:   Type: None
; OTHER-NEXT:   Other [
; OTHER-NEXT:     STV_PROTECTED
; OTHER-NEXT:   ]
; OTHER-NEXT:   Section: .text
; OTHER-NEXT: }
