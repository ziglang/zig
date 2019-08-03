; REQUIRES: x86
; Tests that we accept an archive file without symbol table
; if all the member files are bitcode files.

; RUN: llvm-as -o %t1.o %s
; RUN: llvm-as -o %t2.o %S/Inputs/archive.ll

; RUN: rm -f %t1.a %t2.a
; RUN: llvm-ar crS %t1.a %t2.o
; RUN: llvm-ar crs %t2.a %t2.o

; RUN: ld.lld -o %t -emain %t1.o %t1.a
; RUN: ld.lld -o %t -emain %t1.o %t2.a

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @f()

define i32 @main() {
  call void @f()
  ret i32 0
}

; RUN: echo 'f:' | llvm-mc -triple=x86_64-pc-linux -filetype=obj - -o %t3.o
; RUN: rm -f %t3.a
; RUN: llvm-ar crS %t3.a %t3.o
; RUN: not ld.lld -o /dev/null -emain %t1.o %t3.a 2>&1 | FileCheck -check-prefix=ERR1 %s
; ERR1: error: {{.*}}.a: archive has no index; run ranlib to add one

; RUN: rm -f %t4.a
; RUN: llvm-ar cr %t4.a
; RUN: not ld.lld -o /dev/null -emain %t1.o %t4.a 2>&1 | FileCheck -check-prefix=ERR2 %s
; ERR2: error: undefined symbol: f
