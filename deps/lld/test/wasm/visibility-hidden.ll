; RUN: llc -mtriple=wasm32-unknown-unknown-wasm -filetype=obj -o %t.o %s
; RUN: llc -mtriple=wasm32-unknown-unknown-wasm -filetype=obj %S/Inputs/hidden.ll -o %t2.o
; RUN: llvm-ar rcs %t2.a %t2.o
; RUN: lld -flavor wasm %t.o %t2.a -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that hidden symbols are not exported, whether pulled in from an archive
; or directly.

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

define i32 @_start() {
entry:
  %call1 = call i32 @objectHidden()
  %call2 = call i32 @objectDefault()
  %call3 = call i32 @archiveHidden()
  %call4 = call i32 @archiveDefault()
  ret i32 0
}

; CHECK:        - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:       - Name:            archiveDefault
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           4
; CHECK-NEXT:       - Name:            objectDefault
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:   - Type:
