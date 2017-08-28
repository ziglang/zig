; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-as %S/Inputs/unnamed-addr-drop.ll -o %t2.o
; RUN: ld.lld -m elf_x86_64 %t1.o %t2.o -o %t.so -save-temps -shared
; RUN: llvm-dis %t.so.0.2.internalize.bc -o - | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

@foo = weak constant i32 41

; Check that unnamed_addr is dropped during the merge.
; CHECK: @foo = constant i32 42
