; REQUIRES: x86

;; Make sure that common symbols are properly internalized.
;; In this file, @a does not interpose any symbol in a DSO,
;; so LTO should be able to internelize it.

; RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux /dev/null -o %t.so.o
; RUN: ld.lld -shared -o %t.so %t.so.o

; RUN: llvm-as %s -o %t.o
; RUN: ld.lld -o %t.exe -save-temps %t.o %t.so
; RUN: llvm-dis < %t.exe.0.2.internalize.bc | FileCheck %s

; RUN: ld.lld -pie -o %t.exe -save-temps %t.o
; RUN: llvm-dis < %t.exe.0.2.internalize.bc | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@a = common dso_local local_unnamed_addr global i32 0, align 4
; CHECK-DAG: @a = internal global i32 0, align 4
