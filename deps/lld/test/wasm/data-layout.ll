; RUN: llc -filetype=obj %p/Inputs/hello.ll -o %t.hello.o
; RUN: llc -filetype=obj %s -o %t.o

target triple = "wasm32-unknown-unknown"

@foo = hidden global i32 1, align 4
@aligned_bar = hidden global i32 3, align 16

@hello_str = external global i8*
@external_ref = global i8** @hello_str, align 8

%struct.s = type { i32, i32 }
@local_struct = hidden global %struct.s zeroinitializer, align 4
@local_struct_internal_ptr = hidden local_unnamed_addr global i32* getelementptr inbounds (%struct.s, %struct.s* @local_struct, i32 0, i32 1), align 4

; RUN: wasm-ld -no-gc-sections --allow-undefined --no-entry -o %t.wasm %t.o %t.hello.o
; RUN: obj2yaml %t.wasm | FileCheck %s

; CHECK:        - Type:            MEMORY
; CHECK-NEXT:     Memories:
; CHECK-NEXT:       - Initial:         0x00000002
; CHECK-NEXT:   - Type:            GLOBAL
; CHECK-NEXT:     Globals:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Type:            I32
; CHECK-NEXT:         Mutable:         true
; CHECK-NEXT:         InitExpr:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           66608
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Type:            I32
; CHECK-NEXT:         Mutable:         false
; CHECK-NEXT:         InitExpr:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           66608

; CHECK:         - Type:            DATA
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - SectionOffset:   7
; CHECK-NEXT:         MemoryIndex:     0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1024
; CHECK-NEXT:         Content:         '0100000000000000000000000000000003000000000000002804000024040000'
; CHECK-NEXT:       - SectionOffset:   45
; CHECK-NEXT:         MemoryIndex:     0
; CHECK-NEXT:         Offset:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1056
; CHECK-NEXT:         Content:         '0000000000000000'
; CHECK-NEXT:       - SectionOffset:   59
; CHECK-NEXT:         MemoryIndex:     0
; CHECK-NEXT:         Offset:          
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1064
; CHECK-NEXT:         Content:         68656C6C6F0A00
; CHECK-NEXT:    - Type:            CUSTOM


; RUN: wasm-ld -no-gc-sections --allow-undefined --no-entry \
; RUN:     --initial-memory=131072 --max-memory=131072 -o %t_max.wasm %t.o \
; RUN:     %t.hello.o
; RUN: obj2yaml %t_max.wasm | FileCheck %s -check-prefix=CHECK-MAX

; CHECK-MAX:        - Type:            MEMORY
; CHECK-MAX-NEXT:     Memories:
; CHECK-MAX-NEXT:       - Flags:           [ HAS_MAX ]
; CHECK-MAX-NEXT:         Initial:         0x00000002
; CHECK-MAX-NEXT:         Maximum:         0x00000002

; RUN: wasm-ld -no-gc-sections --allow-undefined --no-entry --shared-memory \
; RUN:     --initial-memory=131072 --max-memory=131072 -o %t_max.wasm %t.o \
; RUN:     %t.hello.o
; RUN: obj2yaml %t_max.wasm | FileCheck %s -check-prefix=CHECK-SHARED

; CHECK-SHARED:        - Type:            MEMORY
; CHECK-SHARED-NEXT:     Memories:
; CHECK-SHARED-NEXT:       - Flags:           [ HAS_MAX, IS_SHARED ]
; CHECK-SHARED-NEXT:         Initial:         0x00000002
; CHECK-SHARED-NEXT:         Maximum:         0x00000002

; RUN: wasm-ld --relocatable -o %t_reloc.wasm %t.o %t.hello.o
; RUN: obj2yaml %t_reloc.wasm | FileCheck %s -check-prefix=RELOC

; RELOC:       - Type:            DATA
; RELOC-NEXT:     Relocations:
; RELOC-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_I32
; RELOC-NEXT:         Index:           3
; RELOC-NEXT:         Offset:          0x00000018
; RELOC-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_I32
; RELOC-NEXT:         Index:           4
; RELOC-NEXT:         Offset:          0x0000002E
; RELOC-NEXT:         Addend:          4
; RELOC-NEXT:     Segments:
; RELOC-NEXT:       - SectionOffset:   6
; RELOC-NEXT:         MemoryIndex:     0
; RELOC-NEXT:         Offset:
; RELOC-NEXT:           Opcode:          I32_CONST
; RELOC-NEXT:           Value:           0
; RELOC-NEXT:         Content:         '01000000'
; RELOC-NEXT:       - SectionOffset:   15
; RELOC-NEXT:         MemoryIndex:     0
; RELOC-NEXT:         Offset:
; RELOC-NEXT:           Opcode:          I32_CONST
; RELOC-NEXT:           Value:           16
; RELOC-NEXT:         Content:         '03000000'
; RELOC-NEXT:       - SectionOffset:   24
; RELOC-NEXT:         MemoryIndex:     0
; RELOC-NEXT:         Offset:
; RELOC-NEXT:           Opcode:          I32_CONST
; RELOC-NEXT:           Value:           24
; RELOC-NEXT:         Content:         '28000000'
; RELOC-NEXT:       - SectionOffset:   33
; RELOC-NEXT:         MemoryIndex:     0
; RELOC-NEXT:         Offset:          
; RELOC-NEXT:           Opcode:          I32_CONST
; RELOC-NEXT:           Value:           28
; RELOC-NEXT:         Content:         '0000000000000000'
; RELOC-NEXT:       - SectionOffset:   46
; RELOC-NEXT:         MemoryIndex:     0
; RELOC-NEXT:         Offset:          
; RELOC-NEXT:           Opcode:          I32_CONST
; RELOC-NEXT:           Value:           36
; RELOC-NEXT:         Content:         '20000000'
; RELOC-NEXT:       - SectionOffset:   55
; RELOC-NEXT:         MemoryIndex:     0
; RELOC-NEXT:         Offset:
; RELOC-NEXT:           Opcode:          I32_CONST
; RELOC-NEXT:           Value:           40
; RELOC-NEXT:         Content:         68656C6C6F0A00

; RELOC:          SymbolTable:
; RELOC-NEXT:       - Index:           0
; RELOC-NEXT:         Kind:            DATA
; RELOC-NEXT:         Name:            foo
; RELOC-NEXT:         Flags:           [ VISIBILITY_HIDDEN ]
; RELOC-NEXT:         Segment:         0
; RELOC-NEXT:         Size:            4
; RELOC-NEXT:       - Index:           1
; RELOC-NEXT:         Kind:            DATA
; RELOC-NEXT:         Name:            aligned_bar
; RELOC-NEXT:         Flags:           [ VISIBILITY_HIDDEN ]
; RELOC-NEXT:         Segment:         1
; RELOC-NEXT:         Size:            4
; RELOC-NEXT:       - Index:           2
; RELOC-NEXT:         Kind:            DATA
; RELOC-NEXT:         Name:            external_ref
; RELOC-NEXT:         Flags:           [  ]
; RELOC-NEXT:         Segment:         2
; RELOC-NEXT:         Size:            4
; RELOC-NEXT:       - Index:           3
; RELOC-NEXT:         Kind:            DATA
; RELOC-NEXT:         Name:            hello_str
; RELOC-NEXT:         Flags:           [  ]
; RELOC-NEXT:         Segment:         5
; RELOC-NEXT:         Size:            7
