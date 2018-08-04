; REQUIRES: x86
; RUN: llvm-mc %p/Inputs/shared.s -o %t1.o -filetype=obj -triple=x86_64-unknown-linux
; RUN: ld.lld %t1.o -o %t1.so -shared
; RUN: llvm-as %s -o %t2.o
; RUN: ld.lld %t1.so %t2.o -o %t
; RUN: llvm-readobj -dyn-symbols -dyn-relocations %t | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@.str = private unnamed_addr constant [6 x i8] c"blah\0A\00", align 1

define i32 @_start() {
  %str = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str, i32 0, i32 0))
  ret i32 0
}

declare i32 @printf(i8*, ...)

; Check that puts symbol is present in the dynamic symbol table and
; there's a relocation for it.
; CHECK: Dynamic Relocations {
; CHECK-NEXT:  0x202018 R_X86_64_JUMP_SLOT puts 0x0
; CHECK-NEXT: }

; CHECK: DynamicSymbols [
; CHECK: Symbol {
; CHECK:    Name: puts@
