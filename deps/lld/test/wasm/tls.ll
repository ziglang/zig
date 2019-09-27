; RUN: llc -mattr=+bulk-memory -filetype=obj %s -o %t.o

target triple = "wasm32-unknown-unknown"

@no_tls = global i32 0, align 4
@tls1 = thread_local(localexec) global i32 1, align 4
@tls2 = thread_local(localexec) global i32 1, align 4

define i32* @tls1_addr() {
  ret i32* @tls1
}

define i32* @tls2_addr() {
  ret i32* @tls2
}

; RUN: wasm-ld -no-gc-sections --shared-memory --max-memory=131072 --no-entry -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

; RUN: wasm-ld -no-gc-sections --shared-memory --max-memory=131072 --no-merge-data-segments --no-entry -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

; CHECK:      - Type:            GLOBAL
; CHECK-NEXT:   Globals:
; CHECK-NEXT:     - Index:           0
; CHECK-NEXT:       Type:            I32
; CHECK-NEXT:       Mutable:         true
; CHECK-NEXT:       InitExpr:
; CHECK-NEXT:         Opcode:          I32_CONST
; CHECK-NEXT:         Value:           66576
; CHECK-NEXT:     - Index:           1
; CHECK-NEXT:       Type:            I32
; CHECK-NEXT:       Mutable:         true
; CHECK-NEXT:       InitExpr:
; CHECK-NEXT:         Opcode:          I32_CONST
; CHECK-NEXT:         Value:           0
; CHECK-NEXT:     - Index:           2
; CHECK-NEXT:       Type:            I32
; CHECK-NEXT:       Mutable:         false
; CHECK-NEXT:       InitExpr:
; CHECK-NEXT:         Opcode:          I32_CONST
; CHECK-NEXT:         Value:           8


; CHECK:      - Type:            CODE
; CHECK-NEXT:   Functions:
; Skip __wasm_call_ctors and __wasm_init_memory
; CHECK:          - Index:           2
; CHECK-NEXT:       Locals:          []
; CHECK-NEXT:       Body:            20002401200041004108FC0801000B

; Expected body of __wasm_init_tls:
;   local.get 0
;   global.set  1
;   local.get 0
;   i32.const 0
;   i32.const 8
;   memory.init 1, 0
;   end

; CHECK-NEXT:     - Index:           3
; CHECK-NEXT:       Locals:          []
; CHECK-NEXT:       Body:            2381808080004180808080006A0B

; Expected body of tls1_addr:
;   global.get 1
;   i32.const 0
;   i32.add
;   end

; CHECK-NEXT:     - Index:           4
; CHECK-NEXT:       Locals:          []
; CHECK-NEXT:       Body:            2381808080004184808080006A0B

; Expected body of tls1_addr:
;   global.get 1
;   i32.const 4
;   i32.add
;   end
