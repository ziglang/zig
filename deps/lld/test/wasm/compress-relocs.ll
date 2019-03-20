; RUN: llc -filetype=obj %p/Inputs/call-indirect.ll -o %t2.o
; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld --export-dynamic -o %t.wasm %t2.o %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s
; RUN: wasm-ld --export-dynamic -O2 -o %t-opt.wasm %t2.o %t.o
; RUN: obj2yaml %t-opt.wasm | FileCheck %s
; RUN: not wasm-ld --compress-relocations -o %t-compressed.wasm %t2.o %t.o 2>&1 | FileCheck %s -check-prefix=ERROR
; RUN: wasm-ld --export-dynamic --strip-debug --compress-relocations -o %t-compressed.wasm %t2.o %t.o
; RUN: obj2yaml %t-compressed.wasm | FileCheck %s -check-prefix=COMPRESS

target triple = "wasm32-unknown-unknown-wasm"

define i32 @foo() {
entry:
  ret i32 2
}

define void @_start() local_unnamed_addr {
entry:
  ret void
}

; ERROR: wasm-ld: error: --compress-relocations is incompatible with output debug information. Please pass --strip-debug or --strip-all

; CHECK:    Body:            4100280284888080002100410028028088808000118080808000001A2000118180808000001A0B
; COMPRESS: Body:            41002802840821004100280280081100001A20001101001A0B
