; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: not ld.lld -m elf_x86_64 %t.o %t.o -o %t.so -shared 2>&1 | FileCheck %s

; CHECK:      duplicate symbol: f
; CHECK-NEXT: >>> defined in {{.*}}.o
; CHECK-NEXT: >>> defined in {{.*}}.o

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @f() {
  ret void
}
