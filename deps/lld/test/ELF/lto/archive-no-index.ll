; REQUIRES: x86
; Tests that we suggest that LTO symbols missing from an archive index
; may be the cause of undefined references, but only if we both
; encountered an empty archive index and undefined references (to prevent
; noisy false alarms).

; RUN: llvm-as -o %t1.o %s
; RUN: llvm-as -o %t2.o %S/Inputs/archive.ll

; RUN: rm -f %t1.a %t2.a
; RUN: llvm-ar crS %t1.a %t2.o
; RUN: llvm-ar crs %t2.a %t2.o

; RUN: ld.lld -o %t -emain -m elf_x86_64 %t1.o %t1.a
; RUN: ld.lld -o %t -emain -m elf_x86_64 %t1.o %t2.a

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @f()

define i32 @main() {
  call void @f()
  ret i32 0
}
