; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-as %S/Inputs/common3.ll -o %t2.o
; RUN: ld.lld -m elf_x86_64 %t1.o %t2.o -o %t -shared -save-temps
; RUN: llvm-dis < %t.0.2.internalize.bc | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
@a = common hidden global i32 0, align 8
define i32 @f() {
  %t = load i32, i32* @a, align 4
  ret i32 %t
}

; CHECK: @a = internal global i64 0, align 8
