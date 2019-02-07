target triple = "wasm32-unknown-unknown"

@a = hidden global [6 x i8] c"hello\00", align 1
@b = hidden global [8 x i8] c"goodbye\00", align 1
@c = hidden global [9 x i8] c"whatever\00", align 1
@d = hidden global i32 42, align 4

@e = private constant [9 x i8] c"constant\00", align 1
@f = private constant i8 43, align 4

; RUN: llc -filetype=obj %s -o %t.data-segment-merging.o

; RUN: wasm-ld -no-gc-sections --no-entry -o %t.merged.wasm %t.data-segment-merging.o
; RUN: obj2yaml %t.merged.wasm | FileCheck %s --check-prefix=MERGE
; MERGE:   - Type:            DATA
; MERGE:     Segments:
; MERGE:        Content:         68656C6C6F00676F6F6462796500776861746576657200002A000000
; MERGE:        Content:         636F6E7374616E74000000002B
; MERGE-NOT:    Content:

; RUN: wasm-ld -no-gc-sections --no-entry --no-merge-data-segments -o %t.separate.wasm %t.data-segment-merging.o
; RUN: obj2yaml %t.separate.wasm | FileCheck %s --check-prefix=SEPARATE
; SEPARATE:   - Type:            DATA
; SEPARATE:     Segments:
; SEPARATE:        Content:         68656C6C6F00
; SEPARATE:        Content:         676F6F6462796500
; SEPARATE:        Content:         '776861746576657200'
; SEPARATE:        Content:         2A000000
; SEPARATE:        Content:         636F6E7374616E7400
; SEPARATE:        Content:         2B
; SEPARATE-NOT:    Content:
