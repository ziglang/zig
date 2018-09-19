target triple = "wasm32-unknown-unknown"

@a = hidden global [6 x i8] c"hello\00", align 1
@b = hidden global [8 x i8] c"goodbye\00", align 1
@c = hidden global [9 x i8] c"whatever\00", align 1
@d = hidden global i32 42, align 4

; RUN: llc -filetype=obj %s -o %t.data-segment-merging.o

; RUN: wasm-ld -no-gc-sections --no-entry -o %t.merged.wasm %t.data-segment-merging.o
; RUN: obj2yaml %t.merged.wasm | FileCheck %s --check-prefix=MERGE
; MERGE:       - Type:            DATA
; MERGE-NEXT:    Segments:
; MERGE-NEXT:      - SectionOffset:   7
; MERGE-NEXT:        MemoryIndex:     0
; MERGE-NEXT:        Offset:
; MERGE-NEXT:          Opcode:          I32_CONST
; MERGE-NEXT:          Value:           1024
; MERGE-NEXT:        Content:         68656C6C6F00676F6F6462796500776861746576657200002A000000

; RUN: wasm-ld -no-gc-sections --no-entry --no-merge-data-segments -o %t.separate.wasm %t.data-segment-merging.o
; RUN: obj2yaml %t.separate.wasm | FileCheck %s --check-prefix=SEPARATE
; SEPARATE:       - Type:            DATA
; SEPARATE-NEXT:    Segments:
; SEPARATE-NEXT:      - SectionOffset:   7
; SEPARATE-NEXT:        MemoryIndex:     0
; SEPARATE-NEXT:        Offset:
; SEPARATE-NEXT:          Opcode:          I32_CONST
; SEPARATE-NEXT:          Value:           1024
; SEPARATE-NEXT:        Content:         68656C6C6F00
; SEPARATE-NEXT:      - SectionOffset:   19
; SEPARATE-NEXT:        MemoryIndex:     0
; SEPARATE-NEXT:        Offset:
; SEPARATE-NEXT:          Opcode:          I32_CONST
; SEPARATE-NEXT:          Value:           1030
; SEPARATE-NEXT:        Content:         676F6F6462796500
; SEPARATE-NEXT:      - SectionOffset:   33
; SEPARATE-NEXT:        MemoryIndex:     0
; SEPARATE-NEXT:        Offset:
; SEPARATE-NEXT:          Opcode:          I32_CONST
; SEPARATE-NEXT:          Value:           1038
; SEPARATE-NEXT:        Content:         '776861746576657200'
; SEPARATE-NEXT:      - SectionOffset:   48
; SEPARATE-NEXT:        MemoryIndex:     0
; SEPARATE-NEXT:        Offset:
; SEPARATE-NEXT:          Opcode:          I32_CONST
; SEPARATE-NEXT:          Value:           1048
; SEPARATE-NEXT:        Content:         2A000000
