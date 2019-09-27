; RUN: llc -filetype=obj %s -o %t.atomics.o -mattr=+atomics
; RUN: llc -filetype=obj %s -o %t.bulk-mem.o -mattr=+bulk-memory
; RUN: llc -filetype=obj %s -o %t.atomics.bulk-mem.o -mattr=+atomics,+bulk-memory

; atomics => error
; RUN: not wasm-ld -no-gc-sections --no-entry --shared-memory --max-memory=131072 %t.atomics.o -o %t.atomics.wasm 2>&1 | FileCheck %s --check-prefix ERROR

; atomics, active segments => active segments
; RUN: wasm-ld -no-gc-sections --no-entry --shared-memory --max-memory=131072 --active-segments %t.atomics.o -o %t.atomics.active.wasm
; RUN: obj2yaml %t.atomics.active.wasm | FileCheck %s --check-prefixes ACTIVE,ACTIVE-TLS

; atomics, passive segments => error
; RUN: not wasm-ld -no-gc-sections --no-entry --shared-memory --max-memory=131072 --passive-segments %t.atomics.o -o %t.atomics.passive.wasm 2>&1 | FileCheck %s --check-prefix ERROR

; bulk memory => active segments
; RUN: wasm-ld -no-gc-sections --no-entry %t.bulk-mem.o -o %t.bulk-mem.wasm
; RUN: obj2yaml %t.bulk-mem.wasm | FileCheck %s --check-prefix ACTIVE

; bulk-memory, active segments => active segments
; RUN: wasm-ld -no-gc-sections --no-entry --active-segments %t.bulk-mem.o -o %t.bulk-mem.active.wasm
; RUN: obj2yaml %t.bulk-mem.active.wasm | FileCheck %s --check-prefix ACTIVE

; bulk memory, passive segments => passive segments
; RUN: wasm-ld -no-gc-sections --no-entry --passive-segments %t.bulk-mem.o -o %t.bulk-mem.passive.wasm
; RUN: obj2yaml %t.bulk-mem.passive.wasm | FileCheck %s --check-prefix PASSIVE

; atomics, bulk memory => passive segments
; RUN: wasm-ld -no-gc-sections --no-entry --shared-memory --max-memory=131072 %t.atomics.bulk-mem.o -o %t.atomics.bulk-mem.wasm
; RUN: obj2yaml %t.atomics.bulk-mem.wasm | FileCheck %s --check-prefixes PASSIVE,PASSIVE-TLS

; atomics, bulk memory, active segments => active segments
; RUN: wasm-ld -no-gc-sections --no-entry --shared-memory --max-memory=131072 --active-segments %t.atomics.bulk-mem.o -o %t.atomics.bulk-mem.active.wasm
; RUN: obj2yaml %t.atomics.bulk-mem.active.wasm | FileCheck %s --check-prefixes ACTIVE,ACTIVE-TLS

; atomics, bulk memory, passive segments => passive segments
; RUN: wasm-ld -no-gc-sections --no-entry --shared-memory --max-memory=131072 --passive-segments %t.atomics.bulk-mem.o -o %t.atomics.bulk-mem.passive.wasm
; RUN: obj2yaml %t.atomics.bulk-mem.passive.wasm | FileCheck %s --check-prefixes PASSIVE,PASSIVE-TLS

target triple = "wasm32-unknown-unknown"

@a = hidden global [6 x i8] c"hello\00", align 1
@b = hidden global [8 x i8] c"goodbye\00", align 1
@c = hidden global [10000 x i8] zeroinitializer, align 1
@d = hidden global i32 42, align 4

@e = private constant [9 x i8] c"constant\00", align 1
@f = private constant i8 43, align 4

; ERROR: 'bulk-memory' feature must be used in order to emit passive segments

; ACTIVE-LABEL: - Type:            CODE
; ACTIVE-NEXT:    Functions:
; ACTIVE-NEXT:      - Index:           0
; ACTIVE-NEXT:        Locals:          []
; ACTIVE-NEXT:        Body:            0B
; ACTIVE-TLS-NEXT:  - Index:           1
; ACTIVE-TLS-NEXT:    Locals:          []
; ACTIVE-TLS-NEXT:    Body:            0B
; ACTIVE-NEXT:  - Type:            DATA
; ACTIVE-NEXT:    Segments:
; ACTIVE-NEXT:      - SectionOffset:   7
; ACTIVE-NEXT:        InitFlags:       0
; ACTIVE-NEXT:        Offset:
; ACTIVE-NEXT:          Opcode:          I32_CONST
; ACTIVE-NEXT:          Value:           1024
; ACTIVE-NEXT:        Content:         68656C6C6F00676F6F646279650000002A000000
; ACTIVE-NEXT:      - SectionOffset:   34
; ACTIVE-NEXT:        InitFlags:       0
; ACTIVE-NEXT:        Offset:
; ACTIVE-NEXT:          Opcode:          I32_CONST
; ACTIVE-NEXT:          Value:           1044
; ACTIVE-NEXT:        Content:         '0000000000
; ACTIVE-SAME:                           0000000000'
; ACTIVE-NEXT:      - SectionOffset:   10041
; ACTIVE-NEXT:        InitFlags:       0
; ACTIVE-NEXT:        Offset:
; ACTIVE-NEXT:          Opcode:          I32_CONST
; ACTIVE-NEXT:          Value:           11044
; ACTIVE-NEXT:        Content:         636F6E7374616E74000000002B
; ACTIVE-NEXT:  - Type:            CUSTOM
; ACTIVE-NEXT:    Name:            name
; ACTIVE-NEXT:    FunctionNames:
; ACTIVE-NEXT:      - Index:           0
; ACTIVE-NEXT:        Name:            __wasm_call_ctors
; ACTIVE-TLS-NEXT:  - Index:           1
; ACTIVE-TLS-NEXT:    Name:            __wasm_init_tls

; PASSIVE-LABEL: - Type:            CODE
; PASSIVE-NEXT:    Functions:
; PASSIVE-NEXT:      - Index:           0
; PASSIVE-NEXT:        Locals:          []
; PASSIVE-NEXT:        Body:            10010B
; PASSIVE-NEXT:      - Index:           1
; PASSIVE-NEXT:        Locals:          []
; PASSIVE-NEXT:        Body:            41800841004114FC080000FC090041940841004190CE00FC080100FC090141A4D6004100410DFC080200FC09020B
; PASSIVE-TLS-NEXT:  - Index:           2
; PASSIVE-TLS-NEXT:    Locals:          []
; PASSIVE-TLS-NEXT:    Body:            0B
; PASSIVE-NEXT:  - Type:            DATA
; PASSIVE-NEXT:    Segments:
; PASSIVE-NEXT:      - SectionOffset:   3
; PASSIVE-NEXT:        InitFlags:       1
; PASSIVE-NEXT:        Content:         68656C6C6F00676F6F646279650000002A000000
; PASSIVE-NEXT:      - SectionOffset:   26
; PASSIVE-NEXT:        InitFlags:       1
; PASSIVE-NEXT:        Content:         '0000000000
; PASSIVE-SAME:                           0000000000'
; PASSIVE-NEXT:      - SectionOffset:   10028
; PASSIVE-NEXT:        InitFlags:       1
; PASSIVE-NEXT:        Content:         636F6E7374616E74000000002B
; PASSIVE-NEXT:  - Type:            CUSTOM
; PASSIVE-NEXT:    Name:            name
; PASSIVE-NEXT:    FunctionNames:
; PASSIVE-NEXT:      - Index:           0
; PASSIVE-NEXT:        Name:            __wasm_call_ctors
; PASSIVE-NEXT:      - Index:           1
; PASSIVE-NEXT:        Name:            __wasm_init_memory
; PASSIVE-TLS-NEXT:  - Index:           2
; PASSIVE-TLS-NEXT:    Name:            __wasm_init_tls
