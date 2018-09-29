; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld -r -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

@foo = hidden global [76 x i32] zeroinitializer, align 16

; bar points to the 16th element, which happens to be 64 bytes
; This generates an addend of 64 which, is the value at which
; signed and unsigned LEB encodes will differ.
@bar = hidden local_unnamed_addr global i32* getelementptr inbounds ([76 x i32], [76 x i32]* @foo, i32 0, i32 16), align 4

; CHECK:        - Type:            DATA
; CHECK-NEXT:     Relocations:     
; CHECK-NEXT:       - Type:            R_WEBASSEMBLY_MEMORY_ADDR_I32
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:         Offset:          0x0000013D
; CHECK-NEXT:         Addend:          64
