; RUN: llc -mtriple=wasm32-unknown-unknown-wasm -filetype=obj -o %t.o %s
; RUN: llc -mtriple=wasm32-unknown-unknown-wasm -filetype=obj %S/Inputs/weak-alias.ll -o %t2.o
; RUN: lld -flavor wasm %t.o %t2.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that the strongly defined alias_fn from this file is used both here
; and in call_alias.

define i32 @alias_fn() local_unnamed_addr #1 {
  ret i32 1
}

; Function Attrs: nounwind uwtable
define void @_start() local_unnamed_addr #1 {
entry:
  %call = tail call i32 @alias_fn() #2
  ret void
}

; CHECK:      --- !WASM
; CHECK-NEXT: FileHeader:
; CHECK-NEXT:   Version:         0x00000001
; CHECK-NEXT: Sections:
; CHECK-NEXT:   - Type:            TYPE
; CHECK-NEXT:     Signatures:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         ReturnType:      I32
; CHECK-NEXT:         ParamTypes:
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         ReturnType:      NORESULT
; CHECK-NEXT:         ParamTypes:
; CHECK-NEXT:   - Type:            FUNCTION
; CHECK-NEXT:     FunctionTypes:   [ 0, 1, 0, 0, 0, 0, 0 ]
; CHECK-NEXT:   - Type:            TABLE
; CHECK-NEXT:     Tables:
; CHECK-NEXT:       - ElemType:        ANYFUNC
; CHECK-NEXT:         Limits:
; CHECK-NEXT:           Flags:           [ HAS_MAX ]
; CHECK-NEXT:           Initial:         0x00000003
; CHECK-NEXT:           Maximum:         0x00000003
; CHECK-NEXT:   - Type:            MEMORY
; CHECK-NEXT:     Memories:
; CHECK-NEXT:       - Initial:         0x00000002
; CHECK-NEXT:   - Type:            GLOBAL
; CHECK-NEXT:     Globals:
; CHECK-NEXT:       - Type:            I32
; CHECK-NEXT:         Mutable:         true
; CHECK-NEXT:         InitExpr:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           66560
; CHECK-NEXT:   - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:       - Name:            alias_fn
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            direct_fn
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:       - Name:            call_direct
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           3
; CHECK-NEXT:       - Name:            call_alias
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           4
; CHECK-NEXT:       - Name:            call_alias_ptr
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           5
; CHECK-NEXT:       - Name:            call_direct_ptr
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           6
; CHECK-NEXT:   - Type:            ELEM
; CHECK-NEXT:     Segments:        
; CHECK-NEXT:       - Offset:          
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1
; CHECK-NEXT:         Functions:       [ 0, 2 ]
; CHECK-NEXT:   - Type:            CODE
; CHECK-NEXT:     Functions:
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            41010B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            1080808080001A0B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            41000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            1082808080000B
; CHECK-NEXT:       - Locals:
; CHECK-NEXT:         Body:            1080808080000B
; CHECK-NEXT:       - Locals:          
; CHECK-NEXT:           - Type:            I32
; CHECK-NEXT:             Count:           2
; CHECK-NEXT:         Body:            23808080800041106B220024808080800020004181808080003602081080808080002101200041106A24808080800020010B
; CHECK-NEXT:       - Locals:          
; CHECK-NEXT:           - Type:            I32
; CHECK-NEXT:             Count:           2
; CHECK-NEXT:         Body:            23808080800041106B220024808080800020004182808080003602081082808080002101200041106A24808080800020010B
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            linking
; CHECK-NEXT:     DataSize:        0
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            alias_fn
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Name:            direct_fn
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Name:            call_direct
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Name:            call_alias
; CHECK-NEXT:       - Index:           5
; CHECK-NEXT:         Name:            call_alias_ptr
; CHECK-NEXT:       - Index:           6
; CHECK-NEXT:         Name:            call_direct_ptr
; CHECK-NEXT: ...
