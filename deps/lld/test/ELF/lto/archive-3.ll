; REQUIRES: x86
; RUN: llvm-as %S/Inputs/archive-3.ll -o %t1.o
; RUN: llvm-as %s -o %t2.o

; RUN: ld.lld %t1.o %t2.o  -o %t3 -save-temps
; RUN: llvm-dis %t3.0.2.internalize.bc -o - | FileCheck %s

; RUN: rm -f %t.a
; RUN: llvm-ar rcs %t.a %t1.o
; RUN: ld.lld %t.a %t1.o %t2.o  -o %t3 -save-temps
; RUN: llvm-dis %t3.0.2.internalize.bc -o - | FileCheck %s

; CHECK: define internal void @foo() {

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
define void @_start() {
  ret void
}
