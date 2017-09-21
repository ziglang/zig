; REQUIRES: x86
; Cretae two archive with the same member name
; RUN: rm -f %t1.a %t2.a
; RUN: opt -module-summary %s -o %t.o
; RUN: llvm-ar rcS %t1.a %t.o
; RUN: opt -module-summary %p/Inputs/duplicated-name.ll -o %t.o
; RUN: llvm-ar rcS %t2.a %t.o
; RUN: ld.lld -m elf_x86_64 -shared -o %t.so -uf1 -uf2 %t1.a %t2.a

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @f1() {
  ret void
}
