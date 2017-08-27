; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld -m elf_x86_64 %t.o -o %t2 -save-temps
; RUN: llvm-dis < %t2.0.2.internalize.bc | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @_start() {
  ret void
}

define hidden void @f() {
  ret void
}

@llvm.used = appending global [1 x i8*] [ i8* bitcast (void ()* @f to i8*)]

; Check that f is not internalized.
; CHECK: define hidden void @f()
