; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld --no-entry --print-gc-sections %t.o \
; RUN:     -o %t.wasm 2>&1 | FileCheck -check-prefix=CHECK-GC %s
; RUN: obj2yaml %t.wasm | FileCheck %s

; Check that calling an undefined weak function generates an appropriate stub
; that will fail at runtime with "unreachable".

target triple = "wasm32-unknown-unknown"

declare extern_weak void @weakFunc1()
declare extern_weak void @weakFunc2()         ; same signature
declare extern_weak void @weakFunc3(i32 %arg) ; different
declare extern_weak void @weakFunc4()         ; should be GC'd as not called

; CHECK-GC: removing unused section {{.*}}:(weakFunc4)

define i32 @callWeakFuncs() {
  call void @weakFunc1()
  call void @weakFunc2()
  call void @weakFunc3(i32 2)
  %addr1 = ptrtoint void ()* @weakFunc1 to i32
  %addr4 = ptrtoint void ()* @weakFunc4 to i32
  %sum = add i32 %addr1, %addr4
  ret i32 %sum
}

; CHECK:      --- !WASM
; CHECK-NEXT: FileHeader:
; CHECK-NEXT:   Version:         0x00000001
; CHECK-NEXT: Sections:
; CHECK-NEXT:   - Type:            TYPE
; CHECK-NEXT:     Signatures:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         ReturnType:      NORESULT
; CHECK-NEXT:         ParamTypes:
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         ReturnType:      NORESULT
; CHECK-NEXT:         ParamTypes:
; CHECK-NEXT:           - I32
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         ReturnType:      I32
; CHECK-NEXT:         ParamTypes:
; CHECK-NEXT:   - Type:            FUNCTION
; CHECK-NEXT:     FunctionTypes:   [ 0, 0, 0, 1, 2 ]
; CHECK-NEXT:   - Type:            TABLE
; CHECK-NEXT:     Tables:
; CHECK-NEXT:       - ElemType:        ANYFUNC
; CHECK-NEXT:         Limits:
; CHECK-NEXT:           Flags:           [ HAS_MAX ]
; CHECK-NEXT:           Initial:         0x00000001
; CHECK-NEXT:           Maximum:         0x00000001
; CHECK-NEXT:   - Type:            MEMORY
; CHECK-NEXT:     Memories:
; CHECK-NEXT:       - Initial:         0x00000002
; CHECK-NEXT:   - Type:            GLOBAL
; CHECK-NEXT:     Globals:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Type:            I32
; CHECK-NEXT:         Mutable:         true
; CHECK-NEXT:         InitExpr:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           66560
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Type:            I32
; CHECK-NEXT:         Mutable:         false
; CHECK-NEXT:         InitExpr:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           66560
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Type:            I32
; CHECK-NEXT:         Mutable:         false
; CHECK-NEXT:         InitExpr:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1024
; CHECK-NEXT:   - Type:            EXPORT
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
; CHECK-NEXT:       - Name:            callWeakFuncs
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           4
; CHECK-NEXT:   - Type:            CODE
; CHECK-NEXT:     Functions:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            0B
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            000B
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            000B
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            000B
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            10818080800010828080800041021083808080004180808080004180808080006A0B
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            __wasm_call_ctors
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            undefined function weakFunc1
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Name:            undefined function weakFunc2
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Name:            undefined function weakFunc3
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Name:            callWeakFuncs
; CHECK-NEXT: ...
