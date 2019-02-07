; RUN: llc -filetype=obj -o %t.o %s
; RUN: llc -filetype=obj %S/Inputs/hidden.ll -o %t2.o
; RUN: rm -f %t2.a
; RUN: llvm-ar rcs %t2.a %t2.o

; Test that symbols with hidden visitiblity are not export, even with
; --export-dynamic
; RUN: wasm-ld --export-dynamic %t.o %t2.a -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that symbols with default visitiblity are not exported without
; --export-dynamic
; RUN: wasm-ld %t.o %t2.a -o %t.nodef.wasm
; RUN: obj2yaml %t.nodef.wasm | FileCheck %s -check-prefix=NO-DEFAULT


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
; CHECK-NEXT:       - Name:            objectDefault
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           3
; CHECK-NEXT:       - Name:            archiveDefault
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           5
; CHECK-NEXT:   - Type:


; NO-DEFAULT:        - Type:            EXPORT
; NO-DEFAULT-NEXT:     Exports:
; NO-DEFAULT-NEXT:       - Name:            memory
; NO-DEFAULT-NEXT:         Kind:            MEMORY
; NO-DEFAULT-NEXT:         Index:           0
; NO-DEFAULT-NEXT:       - Name:            __heap_base
; NO-DEFAULT-NEXT:         Kind:            GLOBAL
; NO-DEFAULT-NEXT:         Index:           1
; NO-DEFAULT-NEXT:       - Name:            __data_end
; NO-DEFAULT-NEXT:         Kind:            GLOBAL
; NO-DEFAULT-NEXT:         Index:           2
; NO-DEFAULT-NEXT:       - Name:            _start
; NO-DEFAULT-NEXT:         Kind:            FUNCTION
; NO-DEFAULT-NEXT:         Index:           3
; NO-DEFAULT-NEXT:   - Type:
