; REQUIRES: riscv

; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t
target datalayout = "e-m:e-p:64:64-i64:64-i128:128-n64-S128"
target triple = "riscv64-unknown-elf"

define void @f() {
  ret void
}
