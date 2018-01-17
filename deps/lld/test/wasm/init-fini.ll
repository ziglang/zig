; RUN: llc -mtriple=wasm32-unknown-unknown-wasm -filetype=obj -o %t.o %s
; RUN: llc -mtriple=wasm32-unknown-unknown-wasm -filetype=obj %S/Inputs/global-ctor-dtor.ll -o %t.global-ctor-dtor.o

define hidden void @func1() {
entry:
  ret void
}

define hidden void @func2() {
entry:
  ret void
}

define void @__cxa_atexit() {
  ret void
}

define hidden void @_start() {
entry:
  ret void
}

@llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @func1, i8* null }]

@llvm.global_dtors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @func2, i8* null }]

; RUN: lld -flavor wasm %t.o %t.global-ctor-dtor.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; CHECK:          Name:            linking
; CHECK-NEXT:     DataSize:        0
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:   
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            func1
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            func2
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Name:            __cxa_atexit
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:       - Index:           4
; CHECK-NEXT:         Name:            .Lcall_dtors
; CHECK-NEXT:       - Index:           5
; CHECK-NEXT:         Name:            .Lregister_call_dtors
; CHECK-NEXT:       - Index:           6
; CHECK-NEXT:         Name:            .Lbitcast
; CHECK-NEXT:       - Index:           7
; CHECK-NEXT:         Name:            myctor
; CHECK-NEXT:       - Index:           8
; CHECK-NEXT:         Name:            mydtor
; CHECK-NEXT:       - Index:           9
; CHECK-NEXT:         Name:            .Lcall_dtors
; CHECK-NEXT:       - Index:           10
; CHECK-NEXT:         Name:            .Lregister_call_dtors
; CHECK-NEXT: ...


; RUN: lld -flavor wasm -r %t.o %t.global-ctor-dtor.o -o %t.reloc.wasm
; RUN: obj2yaml %t.reloc.wasm | FileCheck -check-prefix=RELOC %s

; RELOC:          Name:            linking
; RELOC-NEXT:     DataSize:        0
; RELOC-NEXT:     InitFunctions:   
; RELOC-NEXT:       - Priority:        65535
; RELOC-NEXT:         FunctionIndex:   0
; RELOC-NEXT:       - Priority:        65535
; RELOC-NEXT:         FunctionIndex:   5
; RELOC-NEXT:       - Priority:        65535
; RELOC-NEXT:         FunctionIndex:   7
; RELOC-NEXT:       - Priority:        65535
; RELOC-NEXT:         FunctionIndex:   10
; RELOC-NEXT:   - Type:            CUSTOM
; RELOC-NEXT:     Name:            name
; RELOC-NEXT:     FunctionNames:   
; RELOC-NEXT:       - Index:           0
; RELOC-NEXT:         Name:            func1
; RELOC-NEXT:       - Index:           1
; RELOC-NEXT:         Name:            func2
; RELOC-NEXT:       - Index:           2
; RELOC-NEXT:         Name:            __cxa_atexit
; RELOC-NEXT:       - Index:           3
; RELOC-NEXT:         Name:            _start
; RELOC-NEXT:       - Index:           4
; RELOC-NEXT:         Name:            .Lcall_dtors
; RELOC-NEXT:       - Index:           5
; RELOC-NEXT:         Name:            .Lregister_call_dtors
; RELOC-NEXT:       - Index:           6
; RELOC-NEXT:         Name:            .Lbitcast
; RELOC-NEXT:       - Index:           7
; RELOC-NEXT:         Name:            myctor
; RELOC-NEXT:       - Index:           8
; RELOC-NEXT:         Name:            mydtor
; RELOC-NEXT:       - Index:           9
; RELOC-NEXT:         Name:            .Lcall_dtors
; RELOC-NEXT:       - Index:           10
; RELOC-NEXT:         Name:            .Lregister_call_dtors
; RELOC-NEXT: ...
