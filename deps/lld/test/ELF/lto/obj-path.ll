; REQUIRES: x86

; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/obj-path.ll -o %t2.o

; Test to ensure that obj-path creates the ELF file.
; RUN: rm -f %t4.o
; RUN: ld.lld --plugin-opt=obj-path=%t4.o -shared %t1.o %t2.o -o %t3
; RUN: llvm-readobj --symbols %t3 | FileCheck %s
; RUN: llvm-readobj -h %t4.o1 | FileCheck %s -check-prefix=ELF1
; RUN: llvm-readobj -h %t4.o2 | FileCheck %s -check-prefix=ELF2
; RUN: llvm-nm %t4.o1 2>&1 | FileCheck %s -check-prefix=NM1
; RUN: llvm-nm %t4.o2 2>&1 | FileCheck %s -check-prefix=NM2

; CHECK:      Name: g
; CHECK-NEXT: Value: 0x1010
; CHECK:      Name: f
; CHECK-NEXT: Value: 0x1000

; NM1: T f
; ELF1: Format: ELF64-x86-64

; NM2: T g
; ELF2: Format: ELF64-x86-64

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
