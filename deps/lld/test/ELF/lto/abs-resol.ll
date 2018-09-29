; REQUIRES: x86

; RUN: llvm-as %s -o %t.o
; RUN: llvm-mc -triple=x86_64-pc-linux %p/Inputs/absolute.s -o %t2.o -filetype=obj
; RUN: ld.lld %t.o %t2.o -o %t3.out -pie

; RUN: echo "blah = 0xdeadfeef;" > %t.script
; RUN: ld.lld %t.o -T%t.script -o %t4.out -pie

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@blah = external global i8, align 1

define i8* @_start() {
 ret i8* @blah
}
