; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: ld.lld %t1.o -o %t -shared -save-temps
; RUN: llvm-dis < %t.0.2.internalize.bc | FileCheck %s
; RUN: llvm-readobj --symbols %t | FileCheck %s --check-prefix=SHARED

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@a = common global i8 0, align 8
; CHECK-DAG: @a = common global i8 0, align 8

@b = common hidden global i32 0, align 4
define i32 @f() {
  %t = load i32, i32* @b, align 4
  ret i32 %t
}
; CHECK-DAG: @b = internal global i32 0, align 4

; SHARED: Symbol {
; SHARED:   Name: a
; SHARED-NEXT:   Value:
; SHARED-NEXT:   Size: 1
; SHARED-NEXT:   Binding: Global
; SHARED-NEXT:   Type: Object
; SHARED-NEXT:   Other: 0
; SHARED-NEXT:   Section: .bss
; SHARED-NEXT: }
