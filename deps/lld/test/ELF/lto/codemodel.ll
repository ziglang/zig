; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %ts -mllvm -code-model=small
; RUN: ld.lld %t.o -o %tl -mllvm -code-model=large
; RUN: llvm-objdump -d %ts | FileCheck %s --check-prefix=CHECK-SMALL
; RUN: llvm-objdump -d %tl | FileCheck %s --check-prefix=CHECK-LARGE

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

@data = internal constant [0 x i32] []

define i32* @_start() nounwind readonly {
entry:
; CHECK-SMALL-LABEL:  _start:
; CHECK-SMALL: movl    $2097440, %eax
; CHECK-LARGE-LABEL: _start:
; CHECK-LARGE: movabsq $2097440, %rax
    ret i32* getelementptr ([0 x i32], [0 x i32]* @data, i64 0, i64 0)
}
