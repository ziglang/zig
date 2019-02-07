; RUN: llc -filetype=obj %s -o %t.o
; RUN: llc -filetype=obj %S/Inputs/archive1.ll -o %t.a1.o
; RUN: llc -filetype=obj %S/Inputs/archive2.ll -o %t.a2.o
; RUN: llc -filetype=obj %S/Inputs/archive3.ll -o %t.a3.o
; RUN: llc -filetype=obj %S/Inputs/hello.ll -o %t.hello.o
; RUN: rm -f %t.a
; RUN: llvm-ar rcs %t.a %t.a1.o %t.a2.o %t.a3.o %t.hello.o
; RUN: rm -f %t.imports
; RUN: not wasm-ld %t.a %t.o -o %t.wasm 2>&1 | FileCheck -check-prefix=CHECK-UNDEFINED %s

; CHECK-UNDEFINED: undefined symbol: missing_func

; RUN: echo 'missing_func' > %t.imports
; RUN: wasm-ld -r %t.a %t.o -o %t.wasm

; RUN: llvm-nm -a %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

declare i32 @foo() local_unnamed_addr #1
declare i32 @missing_func() local_unnamed_addr #1

define void @_start() local_unnamed_addr #0 {
entry:
  %call1 = call i32 @foo() #2
  %call2 = call i32 @missing_func() #2
  ret void
}

; Verify that mutually dependant object files in an archive is handled
; correctly.  Since we're using llvm-nm, we must link with --relocatable.
;
; TODO(ncw): Update LLD so that the symbol table is written out for
;   non-relocatable output (with an option to strip it)

; CHECK:      00000004 T _start
; CHECK-NEXT: 00000002 T archive2_symbol
; CHECK-NEXT: 00000001 T bar
; CHECK-NEXT: 00000003 T foo
; CHECK-NEXT:          U missing_func

; Verify that symbols from unused objects don't appear in the symbol table
; CHECK-NOT: hello

; Specifying the same archive twice is allowed.
; RUN: wasm-ld %t.a %t.a %t.o -o %t.wasm

; Verfiy errors include library name
; RUN: not wasm-ld -u archive2_symbol -u archive3_symbol %t.a %t.o -o %t.wasm 2>&1 | FileCheck -check-prefix=CHECK-DUP %s
; CHECK-DUP: error: duplicate symbol: bar
; CHECK-DUP: >>> defined in {{.*}}.a({{.*}}.a2.o)
; CHECK-DUP: >>> defined in {{.*}}.a({{.*}}.a3.o)
