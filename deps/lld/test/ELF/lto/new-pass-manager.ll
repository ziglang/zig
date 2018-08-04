; REQUIRES: x86
; RUN: opt -module-summary %s -o %t.o

; Test new-pass-manager and debug-pass-manager option
; RUN: ld.lld --plugin-opt=new-pass-manager --plugin-opt=debug-pass-manager -o %t2.o %t.o 2>&1 | FileCheck %s
; RUN: ld.lld --plugin-opt=new-pass-manager --lto-debug-pass-manager -o %t2.o %t.o 2>&1 | FileCheck %s
; RUN: ld.lld --lto-new-pass-manager --plugin-opt=debug-pass-manager -o %t2.o %t.o 2>&1 | FileCheck %s
; RUN: ld.lld --lto-new-pass-manager --lto-debug-pass-manager -o %t2.o %t.o 2>&1 | FileCheck %s

; CHECK: Starting llvm::Module pass manager run
; CHECK: Finished llvm::Module pass manager run

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
