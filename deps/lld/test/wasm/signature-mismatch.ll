; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj %p/Inputs/call-ret32.ll -o %t.call.o
; RUN: llc -filetype=obj %s -o %t.main.o
; RUN: wasm-ld --export=call_ret32 --export=ret32 -o %t.wasm %t.main.o %t.ret32.o %t.call.o 2>&1 | FileCheck %s -check-prefix=WARN
; RUN: obj2yaml %t.wasm | FileCheck %s -check-prefix=YAML
; RUN: not wasm-ld --fatal-warnings -o %t.wasm %t.main.o %t.ret32.o %t.call.o 2>&1 | FileCheck %s -check-prefix=ERROR

target triple = "wasm32-unknown-unknown"

@ret32_address_main = global i32 (i32, i64, i32)* @ret32, align 4

; Function Attrs: nounwind
define hidden void @_start() local_unnamed_addr {
entry:
  %call1 = call i32 @ret32(i32 1, i64 2, i32 3)
  %addr = load i32 (i32, i64, i32)*, i32 (i32, i64, i32)** @ret32_address_main, align 4
  %call2 = call i32 %addr(i32 1, i64 2, i32 3)
  ret void
}

declare i32 @ret32(i32, i64, i32) local_unnamed_addr

; WARN: warning: function signature mismatch: ret32
; WARN-NEXT: >>> defined as (i32, i64, i32) -> i32 in {{.*}}.main.o
; WARN-NEXT: >>> defined as (f32) -> i32 in {{.*}}.ret32.o

; ERROR: error: function signature mismatch: ret32
; ERROR-NEXT: >>> defined as (i32, i64, i32) -> i32 in {{.*}}.main.o
; ERROR-NEXT: >>> defined as (f32) -> i32 in {{.*}}.ret32.o

; YAML:        - Type:            EXPORT
; YAML:           - Name:            ret32
; YAML-NEXT:        Kind:            FUNCTION
; YAML-NEXT:        Index:           2
; YAML-NEXT:      - Name:            call_ret32
; YAML-NEXT:        Kind:            FUNCTION
; YAML-NEXT:        Index:           3

; YAML:        - Type:            CUSTOM
; YAML-NEXT:     Name:            name
; YAML-NEXT:     FunctionNames:   
; YAML-NEXT:       - Index:           0
; YAML-NEXT:         Name:            'unreachable:ret32'
; YAML-NEXT:       - Index:           1
; YAML-NEXT:         Name:            _start
; YAML-NEXT:       - Index:           2
; YAML-NEXT:         Name:            ret32
; YAML-NEXT:       - Index:           3
; YAML-NEXT:         Name:            call_ret32
; YAML-NEXT: ...

