; RUN: llc -filetype=obj %s -o %t.o
; RUN: yaml2obj %S/Inputs/undefined-globals.yaml -o %t_globals.o
; RUN: wasm-ld --allow-undefined -o %t1.wasm %t.o %t_globals.o

target triple = "wasm32-unknown-unknown"

declare i64 @unused_undef_function(i64 %arg)

declare i32 @used_undef_function()

declare i64 @use_undef_global()

define hidden void @foo() {
entry:
  call i64 @unused_undef_function(i64 0)
  ret void
}

define hidden void @_start() {
entry:
  call i32 @used_undef_function()
  call i64 @use_undef_global()
  ret void
}

; RUN: obj2yaml %t1.wasm | FileCheck %s

; CHECK:        - Type:            IMPORT
; CHECK-NEXT:     Imports:
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           used_undef_function
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         SigIndex:        0
; CHECK-NEXT:       - Module:          env
; CHECK-NEXT:         Field:           used_undef_global
; CHECK-NEXT:         Kind:            GLOBAL
; CHECK-NEXT:         GlobalType:      I64
; CHECK-NEXT:         GlobalMutable:   true
; CHECK-NEXT:   - Type:
; CHECK:        - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            used_undef_function
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Name:            use_undef_global
; CHECK-NEXT: ...

; RUN: wasm-ld --no-gc-sections --allow-undefined \
; RUN:     -o %t1.no-gc.wasm %t.o %t_globals.o
; RUN: obj2yaml %t1.no-gc.wasm | FileCheck %s -check-prefix=NO-GC

; NO-GC:        - Type:            IMPORT
; NO-GC-NEXT:     Imports:
; NO-GC-NEXT:       - Module:          env
; NO-GC-NEXT:         Field:           unused_undef_function
; NO-GC-NEXT:         Kind:            FUNCTION
; NO-GC-NEXT:         SigIndex:        0
; NO-GC-NEXT:       - Module:          env
; NO-GC-NEXT:         Field:           used_undef_function
; NO-GC-NEXT:         Kind:            FUNCTION
; NO-GC-NEXT:         SigIndex:        1
; NO-GC-NEXT:       - Module:          env
; NO-GC-NEXT:         Field:           unused_undef_global
; NO-GC-NEXT:         Kind:            GLOBAL
; NO-GC-NEXT:         GlobalType:      I64
; NO-GC-NEXT:         GlobalMutable:   true
; NO-GC-NEXT:       - Module:          env
; NO-GC-NEXT:         Field:           used_undef_global
; NO-GC-NEXT:         Kind:            GLOBAL
; NO-GC-NEXT:         GlobalType:      I64
; NO-GC-NEXT:         GlobalMutable:   true
; NO-GC-NEXT:   - Type:
; NO-GC:        - Type:            CUSTOM
; NO-GC-NEXT:     Name:            name
; NO-GC-NEXT:     FunctionNames:
; NO-GC-NEXT:       - Index:           0
; NO-GC-NEXT:         Name:            unused_undef_function
; NO-GC-NEXT:       - Index:           1
; NO-GC-NEXT:         Name:            used_undef_function
; NO-GC-NEXT:       - Index:           2
; NO-GC-NEXT:         Name:            __wasm_call_ctors
; NO-GC-NEXT:       - Index:           3
; NO-GC-NEXT:         Name:            foo
; NO-GC-NEXT:       - Index:           4
; NO-GC-NEXT:         Name:            _start
; NO-GC-NEXT:       - Index:           5
; NO-GC-NEXT:         Name:            use_undef_global
; NO-GC-NEXT: ...
