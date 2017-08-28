; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-mc -triple=x86_64-pc-linux %p/Inputs/common.s -o %t2.o -filetype=obj
; RUN: ld.lld %t1.o %t2.o -o %t.so -shared
; RUN: llvm-readobj -s -t %t.so | FileCheck %s

; CHECK:      Name: .bss
; CHECK-NEXT: Type: SHT_NOBITS
; CHECK-NEXT: Flags [
; CHECK-NEXT:   SHF_ALLOC
; CHECK-NEXT:   SHF_WRITE
; CHECK-NEXT: ]
; CHECK-NEXT: Address:
; CHECK-NEXT: Offset:
; CHECK-NEXT: Size: 8
; CHECK-NEXT: Link: 0
; CHECK-NEXT: Info: 0
; CHECK-NEXT: AddressAlignment: 8

; CHECK:      Name: a
; CHECK-NEXT: Value:
; CHECK-NEXT: Size: 8
; CHECK-NEXT: Binding: Global
; CHECK-NEXT: Type: Object
; CHECK-NEXT: Other: 0
; CHECK-NEXT: Section: .bss

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@a = common global i32 0, align 8
