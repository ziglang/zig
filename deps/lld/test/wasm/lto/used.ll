; RUN: llc %s -o %t.o -filetype=obj
; RUN: llvm-as %S/Inputs/used.ll -o %t1.o
; RUN: wasm-ld %t.o %t1.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; Verify that symbols references from regular objects are preserved by LTO

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

declare void @bar()

@foo = external global i32

define void @_start() {
  %val = load i32, i32* @foo, align 4
  %tobool = icmp ne i32 %val, 0
  br i1 %tobool, label %callbar, label %return

callbar:
  call void @bar()
  br label %return

return:
  ret void
}

; CHECK:        - Type:            DATA
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - SectionOffset:   7
; CHECK-NEXT:         InitFlags:       0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1024
; CHECK-NEXT:         Content:         '01000000'

; CHECK:       - Type:            CUSTOM
; CHECK-NEXT:    Name:            name
; CHECK-NEXT:    FunctionNames:   
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        Name:            _start
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        Name:            bar
