; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-mc -triple=x86_64-pc-linux %p/Inputs/resolution.s -o %t2.o -filetype=obj
; RUN: ld.lld %t1.o %t2.o -o %t.so -shared
; RUN: llvm-readobj -s --section-data %t.so | FileCheck %s

; CHECK:      Name: .data
; CHECK-NEXT: Type: SHT_PROGBITS
; CHECK-NEXT: Flags [
; CHECK-NEXT:   SHF_ALLOC
; CHECK-NEXT:   SHF_WRITE
; CHECK-NEXT: ]
; CHECK-NEXT: Address:
; CHECK-NEXT: Offset:
; CHECK-NEXT: Size: 4
; CHECK-NEXT: Link: 0
; CHECK-NEXT: Info: 0
; CHECK-NEXT: AddressAlignment: 1
; CHECK-NEXT: EntrySize: 0
; CHECK-NEXT: SectionData (
; CHECK-NEXT:   0000: 09000000 |{{.*}}|
; CHECK-NEXT: )

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@a = weak global i32 8
