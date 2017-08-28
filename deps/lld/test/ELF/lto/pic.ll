; REQUIRES: x86

; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t.so -shared
; RUN: llvm-readobj -r %t.so | FileCheck %s

; CHECK:      Relocations [
; CHECK-NEXT:   Section ({{.*}}) .rela.plt {
; CHECK-NEXT:     R_X86_64_JUMP_SLOT bar 0x0
; CHECK-NEXT:   }
; CHECK-NEXT: ]

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @bar()
define void @foo() {
  call void @bar()
  ret void
}
