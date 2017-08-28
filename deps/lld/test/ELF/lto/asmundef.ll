; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld -m elf_x86_64 %t.o -o %t -save-temps
; RUN: llvm-dis %t.0.4.opt.bc -o - | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

module asm ".weak patatino"
module asm ".equ patatino, foo"

declare void @patatino()

define void @foo() {
  ret void
}

define void @_start() {
  call void @patatino()
  ret void
}

; CHECK: define void @foo

