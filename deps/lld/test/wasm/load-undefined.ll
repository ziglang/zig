; Verify that the -u / --undefined option is able to pull in symbols from
; an archive, and doesn't error when uses to pull in a symbol already loaded.
;
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %S/Inputs/ret64.ll -o %t.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %S/Inputs/ret32.ll -o %t2.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %s -o %t3.o
; RUN: llvm-ar rcs %t2.a %t2.o
; RUN: lld -flavor wasm %t3.o %t2.a %t.o -o %t.wasm -u ret32 --undefined ret64
; RUN: obj2yaml %t.wasm | FileCheck %s

define i32 @_start() local_unnamed_addr {
entry:
  ret i32 1
}

; CHECK:        - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            ret32
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:       - Name:            ret64
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:   - Type:


; Verify that referencing a symbol that doesn't exist won't work
; RUN: not lld -flavor wasm %t3.o -o %t.wasm -u symboldoesnotexist 2>&1 | FileCheck -check-prefix=CHECK-UNDEFINED1 %s
; CHECK-UNDEFINED1: error: undefined symbol: symboldoesnotexist

; RUN: not lld -flavor wasm %t3.o -o %t.wasm --undefined symboldoesnotexist --allow-undefined 2>&1 | FileCheck -check-prefix=CHECK-UNDEFINED2 %s
; CHECK-UNDEFINED2: function forced with --undefined not found: symboldoesnotexist
