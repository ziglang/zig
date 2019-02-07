; RUN: llc -O0 -filetype=obj %s -o %t.o
; RUN: wasm-ld -shared -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

@data = hidden global i32 2, align 4
@indirect_func = local_unnamed_addr global void ()* @foo, align 4
@indirect_func_external = local_unnamed_addr global void ()* @func_external, align 4

define default void @foo() {
entry:
  ; To ensure we use __stack_pointer
  %ptr = alloca i32
  %0 = load i32, i32* @data, align 4
  %1 = load i32, i32* @data_external, align 4
  %2 = load void ()*, void ()** @indirect_func, align 4
  call void %2()
  ret void
}

declare void @func_external()

@data_external = external global i32


; check for dylink section at start

; CHECK:      Sections:
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            dylink
; CHECK-NEXT:     MemorySize:      8
; CHECK-NEXT:     MemoryAlignment: 2
; CHECK-NEXT:     TableSize:       2
; CHECK-NEXT:     TableAlignment:  0

; check for import of __table_base and __memory_base globals

; CHECK:        - Type:            IMPORT
; CHECK-NEXT:     Imports:
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           __indirect_function_table
; CHECK-NEXT:         Kind:            TABLE
; CHECK-NEXT:         Table:
; CHECK-NEXT:           ElemType:        FUNCREF
; CHECK-NEXT:           Limits:
; CHECK-NEXT:             Initial:         0x00000002
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           __stack_pointer
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   true
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           __memory_base
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   false
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           __table_base
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   false

; check for elem segment initialized with __table_base global as offset

; CHECK:        - Type:            ELEM
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - Offset:
; CHECK-NEXT:           Opcode:          GLOBAL_GET
; CHECK-NEXT:           Index:           2
; CHECK-NEXT:         Functions:       [ 2, 0 ]

; check the data segment initialized with __memory_base global as offset

; CHECK:        - Type:            DATA
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - SectionOffset:   6
; CHECK-NEXT:         MemoryIndex:     0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          GLOBAL_GET
; CHECK-NEXT:           Index:           1
; CHECK-NEXT:         Content:         '0000000001000000'
