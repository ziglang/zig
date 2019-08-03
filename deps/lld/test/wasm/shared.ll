; RUN: llc -relocation-model=pic -filetype=obj %s -o %t.o
; RUN: wasm-ld -shared -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-emscripten"

@data = hidden global i32 2, align 4
@data_external = external global i32
@indirect_func = local_unnamed_addr global i32 ()* @foo, align 4
@indirect_func_external = local_unnamed_addr global void ()* @func_external, align 4

; Test data relocations
@data_addr = local_unnamed_addr global i32* @data, align 4
; .. against external symbols
@data_addr_external = local_unnamed_addr global i32* @data_external, align 4
; .. including addends
%struct.s = type { i32, i32 }
@extern_struct = external global %struct.s
@extern_struct_internal_ptr = local_unnamed_addr global i32* getelementptr inbounds (%struct.s, %struct.s* @extern_struct, i32 0, i32 1), align 4

define hidden i32 @foo() {
entry:
  ; To ensure we use __stack_pointer
  %ptr = alloca i32
  %0 = load i32, i32* @data, align 4
  %1 = load i32 ()*, i32 ()** @indirect_func, align 4
  call i32 %1()
  ret i32 %0
}

define hidden i32* @get_data_address() {
entry:
  ret i32* @data_external
}

define hidden i8* @get_func_address() {
entry:
  ret i8* bitcast (void ()* @func_external to i8*)
}

define default i8* @get_local_func_address() {
entry:
  ; Verify that a function which is otherwise not address taken *is* added to
  ; the wasm table with referenced via R_WASM_TABLE_INDEX_REL_SLEB
  ret i8* bitcast (i8* ()* @get_func_address to i8*)
}

declare void @func_external()

; check for dylink section at start

; CHECK:      Sections:
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            dylink
; CHECK-NEXT:     MemorySize:      24
; CHECK-NEXT:     MemoryAlignment: 2
; CHECK-NEXT:     TableSize:       2
; CHECK-NEXT:     TableAlignment:  0
; CHECK-NEXT:     Needed:          []
; CHECK-NEXT:   - Type:            TYPE

; check for import of __table_base and __memory_base globals

; CHECK:        - Type:            IMPORT
; CHECK-NEXT:     Imports:
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Memory:
; CHECK-NEXT:           Initial:       0x0000000
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
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           func_external
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         SigIndex:        1
; CHECK-NEXT:       - Module:          GOT.mem
; CHECK-NEXT:         Field:           indirect_func
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   true
; CHECK-NEXT:       - Module:          GOT.func
; CHECK-NEXT:         Field:           func_external
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   true
; CHECK-NEXT:       - Module:          GOT.mem
; CHECK-NEXT:         Field:           data_external
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   true
; CHECK-NEXT:       - Module:          GOT.mem
; CHECK-NEXT:         Field:           extern_struct
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I32
; CHECK-NEXT:         GlobalMutable:   true
; CHECK-NEXT:   - Type:            FUNCTION

; CHECK:        - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            __wasm_call_ctors
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           1

; check for elem segment initialized with __table_base global as offset

; CHECK:        - Type:            ELEM
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - Offset:
; CHECK-NEXT:           Opcode:          GLOBAL_GET
; CHECK-NEXT:           Index:           2
; CHECK-NEXT:         Functions:       [ 4, 3 ]

; check the generated code in __wasm_call_ctors and __wasm_apply_relocs functions
; TODO(sbc): Disassemble and verify instructions.

; CHECK:        - Type:            CODE
; CHECK-NEXT:     Functions:
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Locals:          []
; CHECK-NEXT:         Body:            10020B
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Locals:          []
; CHECK-NEXT:         Body:            230141046A230241016A360200230141086A23043602002301410C6A230141006A360200230141106A2305360200230141146A230641046A3602000B

; check the data segment initialized with __memory_base global as offset

; CHECK:        - Type:            DATA
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - SectionOffset:   6
; CHECK-NEXT:         InitFlags:       0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          GLOBAL_GET
; CHECK-NEXT:           Index:           1
; CHECK-NEXT:         Content:         '020000000100000000000000000000000000000000000000'
