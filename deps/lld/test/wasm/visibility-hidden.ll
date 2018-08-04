; RUN: llc -filetype=obj -o %t.o %s
; RUN: llc -filetype=obj %S/Inputs/hidden.ll -o %t2.o
; RUN: llvm-ar rcs %t2.a %t2.o
; RUN: wasm-ld %t.o %t2.a -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that hidden symbols are not exported, whether pulled in from an archive
; or directly.

target triple = "wasm32-unknown-unknown"

define hidden i32 @objectHidden() {
entry:
    ret i32 0
}

define i32 @objectDefault() {
entry:
    ret i32 0
}

declare i32 @archiveHidden()
declare i32 @archiveDefault()

define void @_start() {
entry:
  %call1 = call i32 @objectHidden()
  %call2 = call i32 @objectDefault()
  %call3 = call i32 @archiveHidden()
  %call4 = call i32 @archiveDefault()
  ret void
}

; CHECK:        - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            __heap_base
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:       - Name:            __data_end
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           3
; CHECK-NEXT:       - Name:            objectDefault
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:       - Name:            archiveDefault
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           5
; CHECK-NEXT:   - Type:
