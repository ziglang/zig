; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld -m elf_x86_64 %t.o -o %t2 -mllvm -debug-pass=Arguments \
; RUN:   2>&1 | FileCheck -check-prefix=DEFAULT %s
; RUN: ld.lld -m elf_x86_64 %t.o -o %t2 -mllvm -debug-pass=Arguments \
; RUN:   -disable-verify 2>&1 | FileCheck -check-prefix=DISABLE %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @_start() {
  ret void
}

; -disable-verify should disable the verification of bitcode.
; DEFAULT:     Pass Arguments: {{.*}} -verify {{.*}} -verify
; DISABLE-NOT: Pass Arguments: {{.*}} -verify {{.*}} -verify
