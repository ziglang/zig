; REQUIRES: x86
;
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-as %p/Inputs/start-lib1.ll -o %t2.o
; RUN: llvm-as %p/Inputs/start-lib2.ll -o %t3.o
;
; RUN: ld.lld -m elf_x86_64 -shared -o %t3 %t1.o %t2.o %t3.o
; RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=TEST1 %s
; TEST1: Name: bar
; TEST1: Name: foo
;
; RUN: ld.lld -m elf_x86_64 -shared -o %t3 -u bar %t1.o --start-lib %t2.o %t3.o
; RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=TEST2 %s
; TEST2: Name: bar
; TEST2-NOT: Name: foo
;
; RUN: ld.lld -m elf_x86_64 -shared -o %t3 %t1.o --start-lib %t2.o %t3.o
; RUN: llvm-readobj --symbols %t3 | FileCheck --check-prefix=TEST3 %s
; TEST3-NOT: Name: bar
; TEST3-NOT: Name: foo

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @_start() {
  ret void
}
