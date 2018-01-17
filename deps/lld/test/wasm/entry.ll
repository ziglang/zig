; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %s -o %t.o
; RUN: lld -flavor wasm -e entry -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s
; RUN: lld -flavor wasm --entry=entry -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

define void @entry() local_unnamed_addr #0 {
entry:
  ret void
}

; CHECK:   - Type:            EXPORT
; CHECK:     Exports:
; CHECK:       - Name:            memory
; CHECK:         Kind:            MEMORY
; CHECK:         Index:           0
; CHECK:       - Name:            entry
; CHECK:         Kind:            FUNCTION
; CHECK:         Index:           0
