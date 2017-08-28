; REQUIRES: x86
; RUN: llvm-mc %p/Inputs/shared.s -o %t386.o -filetype=obj -triple=i386-pc-linux
; RUN: ld.lld %t386.o -o %ti386.so -shared
; RUN: llvm-as %s -o %tx64.o
; RUN: not ld.lld %ti386.so %tx64.o -o %t 2>&1 | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; CHECK: {{.*}}x64.o is incompatible with {{.*}}i386.so
