; RUN: llc -filetype=obj -o %t.o %s
; RUN: llc -filetype=obj %S/Inputs/global-ctor-dtor.ll -o %t.global-ctor-dtor.o

target triple = "wasm32-unknown-unknown"

define hidden void @func1() {
entry:
  ret void
}

define hidden void @func2() {
entry:
  ret void
}

define hidden void @func3() {
entry:
  ret void
}

define hidden void @func4() {
entry:
  ret void
}

declare hidden void @externCtor()
declare hidden void @externDtor()
declare hidden void @__wasm_call_ctors()

define i32 @__cxa_atexit(i32 %func, i32 %arg, i32 %dso_handle) {
  ret i32 0
}

define hidden void @_start() {
entry:
  call void @__wasm_call_ctors();
  ret void
}

@llvm.global_ctors = appending global [4 x { i32, void ()*, i8* }] [
  { i32, void ()*, i8* } { i32 1001, void ()* @func1, i8* null },
  { i32, void ()*, i8* } { i32 101, void ()* @func1, i8* null },
  { i32, void ()*, i8* } { i32 101, void ()* @func2, i8* null },
  { i32, void ()*, i8* } { i32 4000, void ()* @externCtor, i8* null }
]

@llvm.global_dtors = appending global [4 x { i32, void ()*, i8* }] [
  { i32, void ()*, i8* } { i32 1001, void ()* @func3, i8* null },
  { i32, void ()*, i8* } { i32 101, void ()* @func3, i8* null },
  { i32, void ()*, i8* } { i32 101, void ()* @func4, i8* null },
  { i32, void ()*, i8* } { i32 4000, void ()* @externDtor, i8* null }
]

; RUN: wasm-ld --allow-undefined %t.o %t.global-ctor-dtor.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; CHECK:        - Type:            IMPORT
; CHECK-NEXT:     Imports:
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           externDtor
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         SigIndex:        0
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           externCtor
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         SigIndex:        0
; CHECK:        - Type:            ELEM
; CHECK-NEXT:     Segments:
; CHECK-NEXT:       - Offset:
; CHECK-NEXT:           Opcode:          I32_CONST
; CHECK-NEXT:           Value:           1
; CHECK-NEXT:         Functions:       [ 9, 11, 13, 17, 19, 21 ]
; CHECK-NEXT:   - Type:            CODE
; CHECK-NEXT:     Functions:
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            10031004100A100F1012100F10141003100C100F10161001100E0B
; CHECK:            - Index:           22
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            02404186808080004100418088808000108780808000450D0000000B0B
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            externDtor
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            externCtor
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Name:            __wasm_call_ctors
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Name:            func1
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Name:            func2
; CHECK-NEXT:       - Index:           5
; CHECK-NEXT:         Name:            func3
; CHECK-NEXT:       - Index:           6
; CHECK-NEXT:         Name:            func4
; CHECK-NEXT:       - Index:           7
; CHECK-NEXT:         Name:            __cxa_atexit
; CHECK-NEXT:       - Index:           8
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:       - Index:           9
; CHECK-NEXT:         Name:            .Lcall_dtors.101
; CHECK-NEXT:       - Index:           10
; CHECK-NEXT:         Name:            .Lregister_call_dtors.101
; CHECK-NEXT:       - Index:           11
; CHECK-NEXT:         Name:            .Lcall_dtors.1001
; CHECK-NEXT:       - Index:           12
; CHECK-NEXT:         Name:            .Lregister_call_dtors.1001
; CHECK-NEXT:       - Index:           13
; CHECK-NEXT:         Name:            .Lcall_dtors.4000
; CHECK-NEXT:       - Index:           14
; CHECK-NEXT:         Name:            .Lregister_call_dtors.4000
; CHECK-NEXT:       - Index:           15
; CHECK-NEXT:         Name:            myctor
; CHECK-NEXT:       - Index:           16
; CHECK-NEXT:         Name:            mydtor
; CHECK-NEXT:       - Index:           17
; CHECK-NEXT:         Name:            .Lcall_dtors.101
; CHECK-NEXT:       - Index:           18
; CHECK-NEXT:         Name:            .Lregister_call_dtors.101
; CHECK-NEXT:       - Index:           19
; CHECK-NEXT:         Name:            .Lcall_dtors.202
; CHECK-NEXT:       - Index:           20
; CHECK-NEXT:         Name:            .Lregister_call_dtors.202
; CHECK-NEXT:       - Index:           21
; CHECK-NEXT:         Name:            .Lcall_dtors.2002
; CHECK-NEXT:       - Index:           22
; CHECK-NEXT:         Name:            .Lregister_call_dtors.2002
; CHECK-NEXT: ...

; RUN: wasm-ld -r %t.o %t.global-ctor-dtor.o -o %t.reloc.wasm
; RUN: llvm-readobj --symbols --sections %t.reloc.wasm | FileCheck -check-prefix=RELOC %s

; RELOC:       Name: linking
; RELOC-NEXT:  InitFunctions [
; RELOC-NEXT:    0 (priority=101)
; RELOC-NEXT:    1 (priority=101)
; RELOC-NEXT:    14 (priority=101)
; RELOC-NEXT:    10 (priority=101)
; RELOC-NEXT:    20 (priority=101)
; RELOC-NEXT:    10 (priority=202)
; RELOC-NEXT:    22 (priority=202)
; RELOC-NEXT:    0 (priority=1001)
; RELOC-NEXT:    16 (priority=1001)
; RELOC-NEXT:    10 (priority=2002)
; RELOC-NEXT:    24 (priority=2002)
; RELOC-NEXT:    9 (priority=4000)
; RELOC-NEXT:    18 (priority=4000)
; RELOC-NEXT:  ]
