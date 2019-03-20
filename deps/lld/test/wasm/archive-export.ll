Test that --export will also fetch lazy symbols from archives

RUN: llc -filetype=obj %S/Inputs/start.ll -o %t.o
RUN: llc -filetype=obj %S/Inputs/archive1.ll -o %t.a1.o
RUN: llc -filetype=obj %S/Inputs/archive2.ll -o %t.a2.o
RUN: rm -f %t.a
RUN: llvm-ar rcs %t.a %t.a1.o %t.a2.o
RUN: wasm-ld --export-dynamic --export=archive2_symbol -o %t.wasm %t.a %t.o
RUN: obj2yaml %t.wasm | FileCheck %s
RUN: wasm-ld --export-dynamic -o %t.wasm %t.a %t.o
RUN: obj2yaml %t.wasm | FileCheck %s -check-prefix=NOEXPORT

CHECK:         Exports:
CHECK-NEXT:       - Name:            memory
CHECK-NEXT:         Kind:            MEMORY
CHECK-NEXT:         Index:           0
CHECK-NEXT:       - Name:            __heap_base
CHECK-NEXT:         Kind:            GLOBAL
CHECK-NEXT:         Index:           1
CHECK-NEXT:       - Name:            __data_end
CHECK-NEXT:         Kind:            GLOBAL
CHECK-NEXT:         Index:           2
CHECK-NEXT:       - Name:            foo
CHECK-NEXT:         Kind:            FUNCTION
CHECK-NEXT:         Index:           2
CHECK-NEXT:       - Name:            bar
CHECK-NEXT:         Kind:            FUNCTION
CHECK-NEXT:         Index:           3
CHECK-NEXT:       - Name:            archive2_symbol
CHECK-NEXT:         Kind:            FUNCTION
CHECK-NEXT:         Index:           4
CHECK-NEXT:       - Name:            _start
CHECK-NEXT:         Kind:            FUNCTION
CHECK-NEXT:         Index:           1
CHECK-NEXT:   - Type:            CODE

NOEXPORT:         Exports:
NOEXPORT-NEXT:       - Name:            memory
NOEXPORT-NEXT:         Kind:            MEMORY
NOEXPORT-NEXT:         Index:           0
NOEXPORT-NEXT:       - Name:            __heap_base
NOEXPORT-NEXT:         Kind:            GLOBAL
NOEXPORT-NEXT:         Index:           1
NOEXPORT-NEXT:       - Name:            __data_end
NOEXPORT-NEXT:         Kind:            GLOBAL
NOEXPORT-NEXT:         Index:           2
NOEXPORT-NEXT:       - Name:            _start
NOEXPORT-NEXT:         Kind:            FUNCTION
NOEXPORT-NEXT:         Index:           1
NOEXPORT-NEXT:   - Type:            CODE
