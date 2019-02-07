; RUN: llc -filetype=obj %s -o %t.o
; RUN: not wasm-ld -o %t.wasm %t.o 2>&1 | FileCheck %s

; CHECK: error: {{.*}}.o: undefined symbol: foo(int)

; RUN: not wasm-ld --no-demangle \
; RUN:     -o %t.wasm %t.o 2>&1 | FileCheck -check-prefix=CHECK-NODEMANGLE %s

; CHECK-NODEMANGLE: error: {{.*}}.o: undefined symbol: _Z3fooi

target triple = "wasm32-unknown-unknown"

declare void @_Z3fooi(i32);

define hidden void @_start() local_unnamed_addr {
entry:
    call void @_Z3fooi(i32 1)
    ret void
}
