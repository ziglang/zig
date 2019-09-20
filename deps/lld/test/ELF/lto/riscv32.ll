; REQUIRES: riscv

; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t
target datalayout = "e-m:e-p:32:32-i64:64-n32-S128"
target triple = "riscv32-unknown-elf"

define void @f() {
  ret void
}
