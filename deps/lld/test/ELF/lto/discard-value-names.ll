; REQUIRES: x86
; RUN: llvm-as %s -o %t.o

; RUN: ld.lld -shared -save-temps %t.o -o %t2.o
; RUN: llvm-dis < %t2.o.0.0.preopt.bc | FileCheck %s

; CHECK: @GlobalValueName
; CHECK: @foo(i32 %in)
; CHECK: somelabel:
; CHECK:  %GV = load i32, i32* @GlobalValueName
; CHECK:  %add = add i32 %in, %GV
; CHECK:  ret i32 %add

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@GlobalValueName = global i32 0

define i32 @foo(i32 %in) {
somelabel:
  %GV = load i32, i32* @GlobalValueName
  %add = add i32 %in, %GV
  ret i32 %add
}
