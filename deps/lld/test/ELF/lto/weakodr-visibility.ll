; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-as %p/Inputs/weakodr-visibility.ll -o %t2.o

; Testcase checks we keep desired visibility of weak 
; symbol in a library even if select different definition.
; We change the order of input files in command line and
; check that linker selects different symbol definitions,
; but keeps `protected` visibility.

; RUN: ld.lld %t1.o %t2.o -o %t.so -shared
; RUN: llvm-readobj -t %t.so | FileCheck %s
; RUN: llvm-objdump -d %t.so | FileCheck %s --check-prefix=FIRST
; CHECK:       Symbol {
; CHECK:        Name: foo
; CHECK-NEXT:   Value:
; CHECK-NEXT:   Size:
; CHECK-NEXT:   Binding: Weak
; CHECK-NEXT:   Type: Function
; CHECK-NEXT:   Other [
; CHECK-NEXT:     STV_PROTECTED
; CHECK-NEXT:   ]
; CHECK-NEXT:   Section:
; CHECK-NEXT: }
; FIRST:      foo:
; FIRST-NEXT:   movl    $41, %eax

; Now swap the files order.
; RUN: ld.lld %t2.o %t1.o -o %t.so -shared
; RUN: llvm-readobj -t %t.so | FileCheck %s
; RUN: llvm-objdump -d %t.so | FileCheck %s --check-prefix=SECOND
; SECOND:      foo:
; SECOND-NEXT:   movl    $42, %eax

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define weak_odr i32 @foo(i8* %this) {
  ret i32 41
}
