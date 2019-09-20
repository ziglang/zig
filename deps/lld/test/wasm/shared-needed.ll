; RUN: llc -filetype=obj %s -o %t.o
; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o

; RUN: wasm-ld -shared -o %t1.so %t.o
; RUN: obj2yaml %t1.so | FileCheck %s -check-prefix=SO1

; RUN: wasm-ld -shared -o %t2.so %t1.so %t.ret32.o
; RUN: obj2yaml %t2.so | FileCheck %s -check-prefix=SO2

target triple = "wasm32-unknown-unknown"

@data = global i32 2, align 4

define default void @foo() {
entry:
  ret void
}

; SO1:      Sections:
; SO1-NEXT:   - Type:            CUSTOM
; SO1-NEXT:     Name:            dylink
; SO1-NEXT:     MemorySize:      4
; SO1-NEXT:     MemoryAlignment: 2
; SO1-NEXT:     TableSize:       0
; SO1-NEXT:     TableAlignment:  0
; SO1-NEXT:     Needed:          []
; SO1-NEXT:   - Type:            TYPE

; SO2:      Sections:
; SO2-NEXT:   - Type:            CUSTOM
; SO2-NEXT:     Name:            dylink
; SO2-NEXT:     MemorySize:      0
; SO2-NEXT:     MemoryAlignment: 0
; SO2-NEXT:     TableSize:       0
; SO2-NEXT:     TableAlignment:  0
; SO2-NEXT:     Needed:
; SO2-NEXT:       - shared-needed.ll.tmp1.so
; SO2-NEXT:   - Type:            TYPE
