; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld --export=_Z3fooi --demangle -o %t_demangle.wasm %t.o
; RUN: obj2yaml %t_demangle.wasm | FileCheck --check-prefixes=CHECK,DEMANGLE %s
; RUN: wasm-ld --export=_Z3fooi --no-demangle -o %t_nodemangle.wasm %t.o
; RUN: obj2yaml %t_nodemangle.wasm | FileCheck --check-prefixes=CHECK,MANGLE %s

target triple = "wasm32-unknown-unknown"

; Check that the EXPORT name is still mangled, but that the "name" custom
; section contains the unmangled name.

define void @_Z3fooi(i32 %arg) {
  ret void
}

declare extern_weak void @_Z3bari(i32 %arg)

define void @_start() {
  call void @_Z3fooi(i32 1)
  call void @_Z3bari(i32 1)
  ret void
}

; CHECK:        - Type:            EXPORT
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
; CHECK-NEXT:       - Name:            _Z3fooi
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           3
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
; CHECK-NEXT:         Body:            0B
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Locals:
; CHECK-NEXT:         Body:            410110828080800041011081808080000B
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            __wasm_call_ctors
; CHECK-NEXT:       - Index:           1
; DEMANGLE-NEXT:      Name:            'undefined function bar(int)'
; MANGLE-NEXT:        Name:            undefined function _Z3bari
; CHECK-NEXT:       - Index:           2
; DEMANGLE-NEXT:      Name:            'foo(int)'
; MANGLE-NEXT:        Name:            _Z3fooi
; CHECK-NEXT:       - Index:           3
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT: ...
