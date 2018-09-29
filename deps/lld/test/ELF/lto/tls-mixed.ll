; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-mc %p/Inputs/tls-mixed.s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
; RUN: ld.lld %t1.o %t2.o -o %t.so -shared

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Should not encounter TLS-ness mismatch for @foo
@foo = external thread_local global i32, align 4
