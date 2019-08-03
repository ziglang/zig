; RUN: llc -filetype=obj %s -o %t.o

target triple = "wasm32-unknown-unknown"

define hidden void @entry() local_unnamed_addr #0 {
entry:
  ret void
}

; RUN: wasm-ld -e entry -o %t1.wasm %t.o
; RUN: obj2yaml %t1.wasm | FileCheck %s
; RUN: wasm-ld --entry=entry -o %t2.wasm %t.o
; RUN: obj2yaml %t2.wasm | FileCheck %s

; CHECK:        - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            entry
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:   - Type:

; The __wasm_call_ctors is somewhat special since its created by the linker.
; Make sure we can use it as the entry point if we choose
; RUN: wasm-ld --entry=__wasm_call_ctors -o %t3.wasm %t.o
; RUN: obj2yaml %t3.wasm | FileCheck %s -check-prefix=CHECK-CTOR

; CHECK-CTOR:        - Type:            EXPORT
; CHECK-CTOR-NEXT:     Exports:
; CHECK-CTOR-NEXT:       - Name:            memory
; CHECK-CTOR-NEXT:         Kind:            MEMORY
; CHECK-CTOR-NEXT:         Index:           0
; CHECK-CTOR-NEXT:       - Name:            __wasm_call_ctors
; CHECK-CTOR-NEXT:         Kind:            FUNCTION
; CHECK-CTOR-NEXT:         Index:           0
; CHECK-CTOR-NEXT:   - Type:
